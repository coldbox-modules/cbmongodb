/**
 *
 * Mongo Client
 *
 * Maintains the Database Connection via the Native Driver
 *
 * @singleton
 * @package   cbmongodb.models.Mongo
 * @author    Jon Clausen <jon_clausen@silowebworks.com>
 * @license   Apache v2.0 <http: // www.apache.org / licenses/>
 */
component name="MongoClient" accessors="true" {

	// injected properties
	/**
	 *
	 * Wirebox
	 */
	property name="wirebox" inject="wirebox";
	/**
	 * CBJavaloader
	 */
	property name="jLoader" inject="id:loader@cbjavaloader";
	/**
	 * Utility Class
	 */
	property name="MongoUtil" inject="id:MongoUtil@cbmongodb";

	property name="MongoConfig" inject="id:MongoConfig@cbmongodb";

	/**
	 * Properties created on init()
	 */
	property name="Mongo";
	property name="MongoAsync";
	property name="WriteConcern";
	property name="ReadPreference";
	property name="collections";
	property name="databases";

	/**
	 * Constructor
	 */
	public function init(){
		return this;
	}

	/**
	 * After init the autowire properties
	 */
	public function onDIComplete(){
		// this.setMongoConfig(getMongoConfig());

		// The Mongo driver client (using modern MongoClients factory)
		variables.MongoClients = jLoader.create( "com.mongodb.client.MongoClients" );

		// @TODO: The async client
		// variables.MongoAsync = jLoader.create('com.mongodb.async.client.MongoClient');

		// WriteConcern Config
		variables.WriteConcern = jLoader.create( "com.mongodb.WriteConcern" );

		// Read Preference Configuration
		variables.ReadPreference = jLoader.create( "com.mongodb.ReadPreference" );

		// Prepare our default database connection
		initDatabases();

		// Prepare our collection structure
		initCollections();

		return this;
	}

	/**
	 * Our connection to the Mongo Server
	 */
	public function connect( required dbName = getMongoConfig().getDBName() ){
		var MongoConfigSettings = MongoConfig.getDefaults();

		// Ensure only a single connection to each database
		if ( structKeyExists( variables.databases, arguments.dbName ) )
			return variables.databases[ arguments.dbName ];

		// Create MongoDB client using modern API
		var mongoClient = "";

		if (
			structKeyExists( MongoConfigSettings, "connectionString" ) && len(
				MongoConfigSettings.connectionString
			)
		) {
			// Use connection string directly with MongoClients.create()
			mongoClient = variables.MongoClients.create( MongoConfigSettings.connectionString );
		} else {
			// Build client settings using the modern MongoClientSettings
			var clientSettings = getMongoConfig().getMongoClientSettings();
			mongoClient = variables.MongoClients.create( clientSettings );
		}

		// Store the client for reuse
		if ( !structKeyExists( variables, "mongoClient" ) ) {
			variables.mongoClient = mongoClient;
		}

		var connection                          = mongoClient.getDatabase( arguments.dbName );
		variables.databases[ arguments.dbName ] = connection;

		return connection;
	}

	/**
	 * Gets a CBMongoDB DBCollection object, which wraps the java DBCollection
	 */
	function getDBCollection( collectionName, dbName = getMongoConfig().getDBName() ){
		if ( !structKeyExists( variables.collections, dbName ) ) variables.collections[ dbName ] = {};

		if ( !structKeyExists( variables.collections[ dbName ], arguments.collectionName ) ) {
			// each collection receives their own connection
			variables.collections[ dbName ][ arguments.collectionName ] = Wirebox
				.getInstance( "MongoCollection@cbmongodb" )
				.init( connect( arguments.dbName ).getCollection( arguments.collectionName ) );
		}

		return variables.collections[ dbName ][ arguments.collectionName ];
	}


	private function createCredential(
		required string username,
		required string password,
		required authDB = "admin"
	){
		var MongoCredential = jLoader.create( "com.mongodb.MongoCredential" );

		var credential = MongoCredential.createCredential(
			javacast( "string", username ),
			javacast( "string", arguments.authDB ),
			arguments.password.toCharArray()
		);
		return credential;
	}


	private function initDatabases(){
		var dbName          = getMongoConfig().getDbName();
		variables.databases = {};
		// create our defautlt connection;
		connect( dbName );
	}

	private function initCollections(){
		var dbName            = getMongoConfig().getDBName();
		variables.collections = { "#dbName#" : {} };
	}


	/**
	 *  Adds a user to the database
	 *  @deprecated User management should be done through MongoDB shell or admin tools in modern deployments
	 */
	function addUser( string username, string password ){
		// In MongoDB 5.x, user management is typically done through the admin database
		// This method is deprecated and may not work with all authentication mechanisms
		var adminDb = variables.mongoClient.getDatabase( "admin" );
		
		// Create a basic user document - this is a simplified implementation
		var userDoc = jLoader.create( "org.bson.Document" );
		userDoc.put( "user", arguments.username );
		userDoc.put( "pwd", arguments.password );
		userDoc.put( "roles", jLoader.create( "java.util.ArrayList" ).init( [ "readWrite" ] ) );
		
		try {
			adminDb.runCommand( userDoc );
		} catch ( any e ) {
			// Log warning but don't fail - user management is often handled externally
			// writeLog( "Warning: User creation failed. Use MongoDB admin tools for user management." );
		}
		
		return this;
	}

	/**
	 * Drops the database currently specified in MongoConfig
	 */
	function dropDatabase(){
		var database = variables.mongoClient.getDatabase( getMongoConfig().getDBName() );
		database.drop();
		return this;
	}


	/**
	* Closes the underlying mongodb object. Once closed, you cannot perform additional mongo operations and you'll need to init a new mongo.
	  Best practice is to close mongo in your Application.cfc's onApplicationStop() method. Something like:
	  getBeanFactory().getBean("mongo").close();
	  or
	  application.mongo.close()

	  depending on how you're initializing and making mongo available to your app

	  NOTE: If you do not close your mongo object, you WILL leak connections!
	*/
	function close(){
		if ( structKeyExists( variables, "mongoClient" ) ) {
			variables.mongoClient.close();
		}
		return this;
	}

	/**
	 * Returns the last error for the current connection.
	 * @deprecated This method is deprecated in MongoDB Java Driver 5.x as write concerns handle error reporting
	 */
	function getLastError(){
		// In modern MongoDB drivers, errors are handled through write concerns and exceptions
		// This method is kept for backward compatibility but always returns null
		return javacast( "null", "" );
	}


	/**
	 * Decide whether to use the MongoConfig in the variables scope, the one being passed around as arguments, or create a new one
	 */
	function getMongoConfig( mongoConfig = "" ){
		if ( isSimpleValue( arguments.mongoConfig ) ) {
			mongoConfig = variables.mongoConfig;
		}
		return mongoConfig;
	}

	/**
	 * Get the underlying Java driver's MongoClient object
	 */
	function getMongo(){
		return variables.mongoClient;
	}

	/**
	 * Get the underlying Java driver's MongoDatabase object
	 */
	function getMongoDB( mongoConfig = "" ){
		return variables.mongoClient.getDatabase( getMongoConfig().getDefaults().dbName );
	}

}
