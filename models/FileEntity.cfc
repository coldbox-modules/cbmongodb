/**
 *
 * File Entity (e.g. GridFS) for CBMongoDB
 *
 * File Entity object for MongoDB GridFS File Storage
 *
 * @package cbmongodb.models
 * @author  Jon Clausen <jon_clausen@silowebworks.com>
 * @license Apache v2.0 <http: // www.apache.org / licenses/>
 */

component
	name     ="CFMongoFileEntity"
	extends  ="cbmongodb.models.ActiveEntity"
	accessors="true"
{

	property name="bucketName" default="fs";

	// Our file path for temporary file operations
	property name="filePath";

	// Mongo Config
	property name="MongoConfig" inject="id:MongoConfig@cbmongodb";

	// Our GridFS Object (uninstantiated)
	property name="GridFS" inject="id:GridFS@cbmongodb";

	// Javaloader
	property name="jLoader" inject="id:loader@cbjavaloader";

	// Placeholder for the instantiated GridFS Instance
	property name="GridFSInstance";

	// Placeholder for activeEntity fileObject
	property name="GFSFileObject";

	// The GridFS FileID Property
	property
		name    ="fileId"
		schema  ="true"
		required="true";


	public function init(){
		super.init( argumentCollection = arguments );

		return this;
	}

	public function onDIComplete(){
		// Instantiate our Partner GridFS
		var md = getMetadata( this );
		if ( structKeyExists( md, "bucket" ) ) setBucketName( md.bucket );

		if ( structKeyExists( md, "database" ) ) {
			var dbName = md.database;
		} else {
			var dbName = MongoConfig.getDbName();
		}

		setGridFSInstance( GridFS.init( dbName, getBucketName() ) );

		return this;
	}

	/**
	 * Overload to evict()
	 **/
	public function evict(){
		variables.GFSFileObject = javacast( "null", 0 );

		return super.evict();
	}

	/**
	 * Set our file from a path
	 *
	 * @param string filePath 		The system path to the file
	 * @param boolean deleteFile 	Whether to delete the file after it has been loaded to GridFS
	 **/
	public function loadFile( required string filePath, deleteFile = false ){
		if ( !fileExists( filePath ) && fileExists( expandPath( arguments.filePath ) ) )
			arguments.filePath = expandPath( arguments.filePath );

		if ( !fileExists( arguments.filePath ) )
			throw( "File #arguments.filePath# could not be found in the local file system." );

		if ( this.loaded() ) {
			if ( len( getFileId() ) ) GridFSInstance.removeById( getFileId() );
		}

		this.setFileId( GridFSInstance.createFile( argumentCollection = arguments ) );

		return this;
	}

	/**
	 * Overload to delete method to ensure GFS files are deleted as well
	 **/
	boolean function delete( truncate = false ){
		if ( this.loaded() ) {
			variables.GFSFileObject = javacast( "null", 0 );
			GridFSInstance.removeById( getFileId() );
		}

		return super.delete( argumentCollection = arguments );
	}

	/**
	 * Alias for loadFile()
	 **/
	public function setFile( required string filePath, deleteFile = false ){
		variables.GFSFileObject = javacast( "null", 0 );

		return this.loadFile( argumentCollection = arguments );
	}


	/**
	 * Gets the core MongoDB GridFS file object - http://api.mongodb.org/java/current/com/mongodb/gridfs/GridFSFile.html
	 **/
	public function getFileObject(){
		if ( isNull( getGFSFileObject() ) ) {
			setGFSFileObject( GridFSInstance.findById( getFileId() ) );
		}

		return getGFSFileObject();
	}

	/**
	 * Convenience alias for getFileObject()
	 **/
	public function getFile(){
		return getFileObject();
	}

	/**
	 * Returns the file extension of the stored GridFS file
	 **/
	public function getExtension(){
		var gfsFile = getFileObject();
		if ( isNull( gfsFile ) ) throwFileMissing();

		return gfsFile.get( "fileInfo" )[ "extension" ];
	}

	public function getMimeType(){
		var gfsFile = getFileObject();

		if ( isNull( gfsFile ) ) throwFileMissing();

		return gfsFile.get( "fileInfo" )[ "mimetype" ];
	}


	/**
	 * Returns the Java file output stream for the GridFS file object, which may be used for advanced operations
	 **/
	public function getFileInputStream(){
		var gfsFile = getFileObject();

		if ( isNull( gfsFile ) ) throwFileMissing();

		return gfsFile.getInputStream();
	}


	/**
	 * Write the stored GridFS file to a path with optional image transformation arguments
	 *
	 * @param string destination 	Either the full path of the image or a directory to save the image to.  If a directory is provided, the fileId will be used.
	 * @param string imageArgs 		The standard sizing and image options (e.g. - {width:100,height:100,x:100,y:100}) see getImageObject() for additional information
	 **/
	public function writeTo( required string destination, required struct imageArgs = {} ){
		var gfsFile      = getFileObject();
		var fileInfo     = gfsFile.get( "fileInfo" );
		var imageFormats = listToArray( lCase( getReadableImageFormats() ) );

		// if we have a directory, use our file name
		if ( directoryExists( arguments.destination ) ) {
			var fileName = this.getFileId() & "." & fileInfo[ "extension" ];
			arguments.destination &= "/" & fileName;
		}

		if ( listLast( arguments.destination, "." ) != fileInfo[ "extension" ] )
			arguments.destination &= "." & fileInfo[ "extension" ];

		if ( arrayFind( imageFormats, getMimeType() ) ) {
			getImageObject( argumentCollection = imageArgs ).saveAs( arguments.destination );
		} else {
			gfsFile.writeTo( arguments.destination );
		}

		return arguments.destination;
	}

	/**
	 * Image-specfic functions
	 **/

	/**
	 *
	 * Writes an image directly to the browser and aborts the remainder of the request
	 *
	 * @param numeric width 			The maximum width of the image
	 * @param numeric height 		The maximum height of the image
	 * @param any x				The x offset from the upper left corner to crop the image or "center"
	 * @param any y				The y offset from the upper left corner to crop the image or "center"
	 * @param string mimeType 		The mimetype to serve the image - will convert the original mime type to the destination (e.g. - jpg to png)
	 * @param Date expiration 		An optional expiration date to specify in the header for the image content
	 **/
	public void function writeImageToBrowser(
		numeric width,
		numeric height,
		any x = 0,
		any y = 0,
		mimeType,
		expiration
	){
		if ( !isNull( expiration ) and isDate( arguments.expiration ) ) {
			expirationSeconds = dateDiff( "s", now(), arguments.expiration );
			cfheader( name = "expires", value = getHTTPTimeString( arguments.expiration ) );
			cfheader( name = "cache-control", value = "max-age=#expirationSeconds#" );
		}

		if ( isNull( arguments.mimeType ) ) arguments.mimeType = getMimeType();

		var response = getPageContext().getResponse();
		response.setHeader( "Content-Type", arguments.mimeType );

		ImageIO = jLoader.create( "javax.imageio.ImageIO" );
		ImageIO.write(
			getBufferedImage( argumentCollection = arguments ),
			listLast( arguments.mimeType, "/" ),
			response.getOutputStream()
		);
		ImageIO.close();
		abort;
	}

	/**
	 * Returns a native CFML Image (e.g. "<cfimage>") from the GridFS file
	 *
	 * @param numeric width 		The maximum width of the image
	 * @param numeric height 	The maximum height of the image
	 * @param any x			The x offset from the upper left corner to crop the image or "center"
	 * @param any y			The y offset from the upper left corner to crop the image or "center"
	 **/
	public any function getCFImage(
		numeric width,
		numeric height,
		any x = 0,
		any y = 0
	){
		return imageNew( getBufferedImage( argumentCollection = arguments ) );
	}

	/**
	 * Returns a javaxt.io.Image object from the GridFS file
	 * Documentation http://www.javaxt.com/documentation/?jar=javaxt-core&package=javaxt.io&class=Image
	 *
	 * @param numeric width 		The maximum width of the image
	 * @param numeric height 	The maximum height of the image
	 * @param any x			The x offset from the upper left corner of the original image for the crop or "center" (will be recalulated to the new scale)
	 * @param any y			The y offset from the upper left corner of the original image for the crop or "center" (will be recalulated to the new scale)
	 **/
	public any function getImageObject(
		numeric width,
		numeric height,
		any x = 0,
		any y = 0
	){
		var ImageIO = jLoader.create( "javaxt.io.Image" ).init( getFileInputStream() );

		if ( arguments.x != 0 && arguments.y != 0 ) {
			scaleAndCropToFit( ImageIO, ARGUMENTS );
		} else {
			if ( !isNull( arguments.height ) ) ImageIO.setHeight( arguments.height );
			if ( !isNull( arguments.width ) ) ImageIO.setWidth( arguments.width );
		}

		return ImageIO;
	}

	/**
	 * Returns the buffered image object for accessing the raw pixels of an image
	 *
	 * @param numeric width 		The maximum width of the image
	 * @param numeric height 	The maximum height of the image
	 * @param any x			The x offset from the upper left corner to crop the image or "center"
	 * @param any y			The y offset from the upper left corner to crop the image or "center"
	 **/
	public function getBufferedImage(
		numeric width,
		numeric height,
		any x = 0,
		any y = 0
	){
		return getImageObject( argumentCollection = arguments ).getBufferedImage();
	}

	/**
	 * Returns the Buffered Image 2DGraphics object
	 *
	 * @param numeric width 		The maximum width of the image
	 * @param numeric height 	The maximum height of the image
	 * @param any x			The x offset from the upper left corner to crop the image or "center"
	 * @param any y			The y offset from the upper left corner to crop the image or "center"
	 **/
	public function getImageGraphics(
		numeric width,
		numeric height,
		any x = 0,
		any y = 0
	){
		return getBufferedImage( argumentCollection = arguments ).getGraphics();
	}

	/**
	 * Scale an image and crop to fit dimensions
	 *
	 * @param javaxt.io.Image Img 	The Image object to be manipulated
	 * @param string imageArgs 		The standard sizing and image options (e.g. - {width:100,height:100,x:100,y:100}) see getImageObject() for additional information
	 **/
	public any function scaleAndCropToFit( required Img, required struct imageArgs ){
		var originalWidth  = Img.getWidth();
		var originalHeight = Img.getHeight();
		var destWidth      = imageArgs.width;
		var destHeight     = imageArgs.height;

		// Scale down our image proportionally to the largest size necessary
		if ( destHeight > destWidth ) {
			Img.setWidth( destHeight );
		} else if ( destWidth > destHeight ) {
			Img.setHeight( destWidth );
		} else if ( originalHeight > originalWidth ) {
			Img.setWidth( destHeight );
		} else {
			Img.setHeight( destWidth );
		}

		// calculate our differentials
		var diffWidth  = Img.getWidth() / originalWidth;
		var diffHeight = Img.getHeight() / originalHeight;

		// recalculate all of our crop boundaries
		if ( isNumeric( imageArgs.x ) && isNumeric( imageArgs.y ) ) {
			imageArgs.x = diffWidth * imageArgs.x;
			imageArgs.y = diffHeight * imageArgs.y;
		}

		// check for our "center" x/y args
		if ( imageArgs.x == "center" ) {
			imageArgs.x = ( Img.getWidth() / 2 ) - ( destWidth / 2 );
		}
		if ( imageArgs.y == "center" ) {
			imageArgs.y = ( Img.getHeight() / 2 ) - ( destHeight / 2 );
		}

		return Img.crop(
			imageArgs.x,
			imageArgs.y,
			destWidth,
			destHeight
		);
	}

	/**
	 * Throws an error that the file is missing from the GridFS bucket
	 **/
	private function throwFileMissing(){
		throw( "The GridFS file with the id #this.getFileId()# could not be found in the bucket #getBucketName()#" )
	}

}
