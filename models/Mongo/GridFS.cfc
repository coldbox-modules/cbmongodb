/**
 *
 * Mongo GridFS
 *
 * Processes Mongo GridFS Transactions
 *
 * @package cbmongodb.models.Mongo
 * @author  Jon Clausen <jon_clausen@silowebworks.com>
 * @license Apache v2.0 <http: // www.apache.org / licenses/>
 */
component accessors="true" {

	/**
	 * The Mongo Client Instance
	 **/
	property name="mongoClient" inject="id:MongoClient@cbmongodb";
	/**
	 * Mongo Utils
	 **/
	property name="mongoUtil" inject="id:MongoUtil@cbmongodb";
	/**
	 * CBJavaloader
	 **/
	property name="jLoader" inject="id:loader@cbjavaloader";

	property name="moduleSettings" inject="box:moduleSettings:cbmongodb";
	/**
	 * Core GridFS connection properties
	 **/
	property name="dbInstance";
	property name="bucketName";
	property name="GridInstance";


	/**
	 * Initialize The GridFS Instance
	 *
	 * @param string db 		The name of the database to use
	 * @param string bucket 	The name of the bucket to use
	 **/
	function init( string db = "", string bucket = "fs" ){
		// Our implementation depends on the older DB construction
		setBucketName( arguments.bucket );

		if ( len( arguments.db ) > 1 ) {
			setDBInstance( arguments.db );

			setDBInstance( mongoClient.getMongo().getDatabase( variables.dbInstance ) );

			setGridInstance(
				jLoader.create( "com.mongodb.gridfs.GridFS" ).init( variables.dbInstance, variables.bucketName )
			);
		}

		return this;
	}

	function onDIComplete(){
		return this;
	}

	/**
	 * Creates and stores a GridFS file
	 *
	 * @param binary filePath 	The path of the file which will be stored in the db
	 * @param string [fileName] 	The filename for retrieval operations
	 *
	 * @return string 			Returns the string representation of the file ID
	 **/
	public string function createFile(
		required string filePath,
		string fileName,
		required boolean deleteFile = false
	){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );
		var inputStream = jLoader.create( "java.io.FileInputStream" ).init( filePath );

		// create a file name from our path if not specified
		if ( isNull( arguments.fileName ) ) arguments.fileName = listLast( filePath, "/" );
		// default file data storage
		var fileData = {
			"name"      : arguments.fileName,
			"extension" : listLast( arguments.filePath, "." ),
			"mimetype"  : fileGetMimeType( arguments.filePath )
		};

		// image storage processing - skipped if GridFS settings are not enabled
		if ( structKeyExists( moduleSettings, "GridFS" ) && isReadableImage( filePath ) ) {
			var GridFSConfig = moduleSettings.GridFS;
			var img          = imageRead( filePath );

			if ( structKeyExists( GridFSConfig, "imagestorage" ) ) {
				var maxheight = img.height;
				var maxwidth  = img.width;

				if (
					structKeyExists( GridFSConfig.imagestorage, "maxwidth" ) && maxwidth > GridFSConfig.imagestorage.maxwidth
				) {
					maxwidth = GridFSConfig.imagestorage.maxwidth;
				}

				if (
					structKeyExists( GridFSConfig.imagestorage, "maxheight" ) && maxheight > GridFSConfig.imagestorage.maxheight
				) {
					maxheight = GridFSConfig.imagestorage.maxheight;
				}

				if ( maxheight != img.height || maxwidth != img.width ) {
					// throw an error if we are resizing without a tmp directory
					if ( !structKeyExists( GridFSConfig.imagestorage, "tmpDirectory" ) ) {
						throw( "GridFS maximum image sizes are specified but no temporary directory has been provided for processing.  Please ensure a tmpDirectory key exists in your GridFS imagestorage configuration." );
					}

					// ensure our directory exists
					if ( !directoryExists( expandPath( GridFSConfig.imagestorage.tmpDirectory ) ) ) {
						directoryCreate( expandPath( GridFSConfig.imagestorage.tmpDirectory ) );
					}

					// cleanup OS directory separator and replace with generic symbol
					var cleanedFilePath = reReplace( filePath, "(\\|/)", "|", "all" );

					// TODO: this path shoud be within module for all temp files, GridFSConfig.imagestorage.tmpDirectory
					var tmpPath = expandPath( GridFSConfig.imagestorage.tmpDirectory ) & listLast(
						cleanedFilePath,
						"|"
					);

					imageResize( img, maxwidth, maxheight );
					// WriteLog(type="Error", file="cbmongodb", text="#tmpPath#");

					// create a temporary file
					imageWrite( img, tmpPath, true );

					// reload our input stream from the tmp file
					inputStream = jLoader.create( "java.io.FileInputStream" ).init( tmpPath );
				}

				if ( structKeyExists( GridFSConfig.imagestorage, "metadata" ) && GridFSConfig.imagestorage.metadata ) {
					img = imageRead( isDefined( "tmpPath" ) ? tmpPath : arguments.filePath );

					fileData[ "image" ] = { "height" : img[ "height" ], "width" : img[ "width" ] };

					if ( structKeyExists( img, "colormodel" ) )
						fileData[ "image" ][ "colormodel" ] = img[ "colormodel" ];
				}
			}
		}


		var created = GridInstance.createFile( inputStream, arguments.fileName );

		created.put( "fileInfo", mongoUtil.toMongo( fileData ) );

		created.save();

		// clean up our files before returning
		if ( isDefined( "tmpPath" ) && fileExists( tmpPath ) ) fileDelete( tmpPath );

		if ( arguments.deleteFile ) fileDelete( arguments.filePath );

		return created.getId().toString();
	}

	/**
	 * Retreives a GridFS file by ObjectId
	 *
	 * @param any id 	The Mongo ObjectID or _id string representation
	 **/
	function findById( required any id ){
		if ( isSimpleValue( arguments.id ) ) {
			arguments.id = mongoUtil.newObjectIdFromId( arguments.id );
		}

		return GridInstance.findOne( arguments.id );
	}

	/**
	 * Finds a file by search criteria
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function find( required struct criteria ){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );

		return GridInstance.find( mongoUtil.toMongo( arguments.criteria ) );
	}

	/**
	 * Finds an returns a single document with search criteria
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function findOne( required struct criteria ){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );
		if ( structKeyExists( arguments.criteria, "_id" ) )
			arguments.criteria[ "_id" ] = mongoUtil.newObjectIdFromId( arguments.criteria[ "_id" ] );

		return GridInstance.findOne( mongoUtil.toMongo( arguments.criteria ) );
	}

	/**
	 * Returns the iterative cursor of the files contained in the GridFS Bucket
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function getFileList( required struct criteria = {} ){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );

		return GridInstance.getFileList( mongoUtil.toMongo( arguments.criteria ) );
	}

	/**
	 * Removes a GridFS file by id
	 *
	 * @param any id 	The Mongo ObjectID or _id string representation
	 **/
	function removeById( required any id ){
		var criteria = mongoUtil.newIdCriteriaObject( arguments.id );
		return GridInstance.remove( mongoUtil.toMongo( criteria ) );
	}

	/**
	 * Removes a GridFS file by criteria
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function remove( required struct criteria ){
		return GridInstance.remove( mongoUtil.toMongo( arguments.criteria ) );
	}

	private function isReadableImage( filePath ){
		var readableImageFormats = listToArray( lCase( getReadableImageFormats() ) );
		return arrayFind( readableImageFormats, lCase( listLast( filePath, "." ) ) );
	}

}
