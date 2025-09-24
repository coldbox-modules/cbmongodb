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
		setBucketName( arguments.bucket );

		if ( len( arguments.db ) > 1 ) {
			setDBInstance( arguments.db );

			// MongoDB 5.x uses GridFSBucket instead of GridFS
			var mongoDatabase = mongoClient.getMongo().getDatabase( variables.dbInstance );
			var gridFSBuckets = jLoader.create( "com.mongodb.client.gridfs.GridFSBuckets" );
			
			setGridInstance(
				gridFSBuckets.create( mongoDatabase, variables.bucketName )
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


		// MongoDB 5.x GridFSBucket API
		var gridFSUploadOptions = jLoader.create( "com.mongodb.client.gridfs.model.GridFSUploadOptions" );
		gridFSUploadOptions.metadata( mongoUtil.toMongo( fileData ) );

		var objectId = GridInstance.uploadFromStream( arguments.fileName, inputStream, gridFSUploadOptions );

		// clean up our files before returning
		if ( isDefined( "tmpPath" ) && fileExists( tmpPath ) ) fileDelete( tmpPath );

		if ( arguments.deleteFile ) fileDelete( arguments.filePath );

		return objectId.toString();
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

		// MongoDB 5.x GridFSBucket API
		try {
			return GridInstance.openDownloadStream( arguments.id );
		} catch ( any e ) {
			// Return null if file not found
			return javacast( "null", "" );
		}
	}

	/**
	 * Finds a file by search criteria
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function find( required struct criteria ){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );

		// MongoDB 5.x GridFSBucket API
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

		// MongoDB 5.x GridFSBucket API - find returns cursor, so get first result
		var cursor = GridInstance.find( mongoUtil.toMongo( arguments.criteria ) );
		return cursor.first();
	}

	/**
	 * Returns the iterative cursor of the files contained in the GridFS Bucket
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function getFileList( required struct criteria = {} ){
		if ( isNull( GridInstance ) ) throw( "GridFS not initialized." );

		// MongoDB 5.x GridFSBucket API
		return GridInstance.find( mongoUtil.toMongo( arguments.criteria ) );
	}

	/**
	 * Removes a GridFS file by id
	 *
	 * @param any id 	The Mongo ObjectID or _id string representation
	 **/
	function removeById( required any id ){
		if ( isSimpleValue( arguments.id ) ) {
			arguments.id = mongoUtil.newObjectIdFromId( arguments.id );
		}
		
		// MongoDB 5.x GridFSBucket API
		GridInstance.delete( arguments.id );
		return true;
	}

	/**
	 * Removes a GridFS file by criteria
	 *
	 * @param struct criteria 	The CFML struct representation of the Mongo criteria query
	 **/
	function remove( required struct criteria ){
		// MongoDB 5.x approach: find files first, then delete by ID
		var files = GridInstance.find( mongoUtil.toMongo( arguments.criteria ) );
		var deletedCount = 0;
		
		while ( files.hasNext() ) {
			var file = files.next();
			GridInstance.delete( file.getId() );
			deletedCount++;
		}
		
		return deletedCount;
	}

	/**
	 * Downloads a GridFS file to a specified path
	 *
	 * @param any id 			The Mongo ObjectID or _id string representation
	 * @param string filePath 	The path where the file should be saved
	 **/
	function downloadToPath( required any id, required string filePath ){
		if ( isSimpleValue( arguments.id ) ) {
			arguments.id = mongoUtil.newObjectIdFromId( arguments.id );
		}

		// MongoDB 5.x GridFSBucket API
		var outputStream = jLoader.create( "java.io.FileOutputStream" ).init( arguments.filePath );
		try {
			GridInstance.downloadToStream( arguments.id, outputStream );
			return true;
		} catch ( any e ) {
			return false;
		} finally {
			outputStream.close();
		}
	}

	/**
	 * Gets a download stream for a GridFS file
	 *
	 * @param any id 	The Mongo ObjectID or _id string representation
	 **/
	function getDownloadStream( required any id ){
		if ( isSimpleValue( arguments.id ) ) {
			arguments.id = mongoUtil.newObjectIdFromId( arguments.id );
		}

		// MongoDB 5.x GridFSBucket API
		return GridInstance.openDownloadStream( arguments.id );
	}

	private function isReadableImage( filePath ){
		var readableImageFormats = listToArray( lCase( getReadableImageFormats() ) );
		return arrayFind( readableImageFormats, lCase( listLast( filePath, "." ) ) );
	}

}
