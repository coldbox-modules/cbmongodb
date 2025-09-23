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
component accessors="true" {

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

		// The Mongo driver client
		variables.Mongo = jLoader.create( "com.mongodb.MongoClient" );

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

		// New database connections
		var MongoDb = variables.mongo;

		if (
			structKeyExists( MongoConfigSettings, "connectionString" ) && len(
				MongoConfigSettings.connectionString
			)
		) {
			var MongoClientURI = jLoader
				.create( "com.mongodb.MongoClientURI" )
				.init( MongoConfigSettings.connectionString );
			MongoDb.init( MongoClientURI );
		} else if (
			structKeyExists( MongoConfigSettings, "auth" ) && len( MongoConfigSettings.auth.username ) && len(
				MongoConfigSettings.auth.password
			)
		) {
			var MongoCredentials = jLoader.create( "java.util.ArrayList" );
			var MongoServers     = jLoader.create( "java.util.ArrayList" );

			for ( var mongoServer in MongoConfigSettings.servers ) {
				MongoCredentials.add(
					createCredential(
						MongoConfigSettings.auth.username,
						MongoConfigSettings.auth.password,
						structKeyExists( MongoConfigSettings.auth, "db" ) ? MongoConfigSettings.auth.db : "admin"
					)
				);
			}

			MongoDb.init(
				MongoConfig.getServers(),
				MongoCredentials,
				getMongoConfig().getMongoClientOptions()
			);
		} else {
			MongoDb.init( variables.mongoConfig.getServers(), getMongoConfig().getMongoClientOptions() );
		}

		var connection                          = MongoDb.getDatabase( arguments.dbName );
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
	 */
	function addUser( string username, string password ){
		getMongoDB( variables.mongoConfig ).addUser( arguments.username, arguments.password.toCharArray() );
		return this;
	}

	/**
	 * Drops the database currently specified in MongoConfig
	 */
	function dropDatabase(){
		variables.mongo.dropDatabase( variables.mongoConfig.getDBName() );
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
		variables.mongo.close();
		return this;
	}

	/**
	 * Returns the last error for the current connection.
	 */
	function getLastError(){
		return getMongoDB().getLastError();
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
	 * Get the underlying Java driver's Mongo object
	 */
	function getMongo(){
		return variables.mongo;
	}

	/**
	 * Get the underlying Java driver's DB object
	 */
	function getMongoDB( mongoConfig = "" ){
		return getMongo().getDb( getMongoConfig().getDefaults().dbName );
	}

}
