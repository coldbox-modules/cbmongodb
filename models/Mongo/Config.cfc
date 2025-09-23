/**
 *
 * Mongo Config
 *
 * The configuration object passed to MongoDB
 *
 * @singleton
 * @package   cbmongodb.models.Mongo
 * @author    Jon Clausen <jon_clausen@silowebworks.com>
 * @license   Apache v2.0 <http: // www.apache.org / licenses/>
 */
component
	accessors="true"
	output   ="false"
	hint     ="Main configuration for MongoDB Connections"
{

	/**
	 * CBJavaloader
	 **/
	property name="jLoader" inject="id:loader@cbjavaloader";
	property name="configStruct";

	variables.conf = {};


	/**
	 * Constructor
	 *
	 * @hosts Defaults to [{serverName='localhost',serverPort='27017'}]
	 */
	public function init( configStruct ){
		setConfigStruct( arguments.configStruct );

		return this;
	}

	/**
	 * After init the autowire properties
	 */
	public function onDIComplete(){
		if ( isNull( jLoader ) ) {
			application.wirebox.autowire( this );
		}

		var hosts = structKeyExists( configStruct, "hosts" ) ? configStruct.hosts : [
			{ serverName : "localhost", serverPort : "27017" }
		];
		var dbName             = configStruct.db;
		var MongoClientOptions = structKeyExists( configStruct, "clientOptions" ) ? configStruct.clientOptions : {};


		var auth = {
			username : structKeyExists( hosts[ 1 ], "username" ) ? hosts[ 1 ].username : "",
			password : structKeyExists( hosts[ 1 ], "password" ) ? hosts[ 1 ].password : ""
		};

		if ( structKeyExists( hosts[ 1 ], "authenticationDB" ) ) auth[ "db" ] = hosts[ 1 ].authenticationDB;

		variables.conf = {
			connectionString : configStruct.connectionString ?: "",
			dbname           : dbName,
			servers          : jLoader.create( "java.util.ArrayList" ).init(),
			auth             : auth
		};

		var item = "";
		for ( item in hosts ) {
			addServer( item.serverName, item.serverPort );
		}

		// turn the struct of MongoClientOptions into a proper MongoClientSettings object
		buildMongoClientSettings( mongoClientOptions );

		// main entry point for environment-aware configuration; subclasses should do their work in here
		environment = configureEnvironment();

		return this;
	}

	public function addServer( serverName, serverPort ){
		var sa = jLoader.create( "com.mongodb.ServerAddress" ).init( serverName, javacast( "integer", serverPort ) );
		variables.conf.servers.add( sa );

		return this;
	}

	public function removeAllServers(){
		variables.conf.servers.clear();

		return this;
	}

	function buildMongoClientSettings( struct mongoClientOptions ){
		var builder = jLoader.create( "com.mongodb.MongoClientSettings" ).builder();

		// Add authentication if provided
		if ( structKeyExists( variables.conf, "auth" ) && len( variables.conf.auth.username ) && len( variables.conf.auth.password ) ) {
			var credential = jLoader.create( "com.mongodb.MongoCredential" ).createCredential(
				javacast( "string", variables.conf.auth.username ),
				javacast( "string", structKeyExists( variables.conf.auth, "db" ) ? variables.conf.auth.db : "admin" ),
				variables.conf.auth.password.toCharArray()
			);
			builder.credential( credential );
		}

		// Add cluster settings (server addresses)
		if ( structKeyExists( variables.conf, "servers" ) && arrayLen( variables.conf.servers ) ) {
			var clusterSettingsBuilder = jLoader.create( "com.mongodb.connection.ClusterSettings" ).builder();
			clusterSettingsBuilder.hosts( variables.conf.servers );
			builder.applyToClusterSettings( clusterSettingsBuilder.build() );
		}

		for ( var key in mongoClientOptions ) {
			var arg = mongoClientOptions[ key ];
			try {
				switch ( key ) {
					case "readPreference":
						var rp = this.readPreference( arg );
						builder.readPreference( rp );
						break;
					case "readConcern":
						var rc = this.readConcern( arg );
						builder.readConcern( rc );
						break;
					case "writeConcern":
						var wc = this.writeConcern( arg );
						builder.writeConcern( wc );
						break;
					case "connectTimeout":
						var socketSettingsBuilder = jLoader.create( "com.mongodb.connection.SocketSettings" ).builder();
						socketSettingsBuilder.connectTimeout( javacast( "integer", arg ), jLoader.create( "java.util.concurrent.TimeUnit" ).MILLISECONDS );
						builder.applyToSocketSettings( socketSettingsBuilder.build() );
						break;
					case "serverSelectionTimeout":
						var clusterSettingsBuilder = jLoader.create( "com.mongodb.connection.ClusterSettings" ).builder();
						clusterSettingsBuilder.serverSelectionTimeout( javacast( "integer", arg ), jLoader.create( "java.util.concurrent.TimeUnit" ).MILLISECONDS );
						builder.applyToClusterSettings( clusterSettingsBuilder.build() );
						break;
					default:
						// Skip unknown options for compatibility
						break;
				}
			} catch ( any e ) {
				throw(
					message = "The Mongo Client option #key# could not be configured.  Please verify your clientOptions settings contain only valid MongoClientSettings options."
				);
			}
		}

		// Set default server selection timeout if not specified
		if ( !structKeyExists( mongoClientOptions, "serverSelectionTimeout" ) ) {
			var timeoutMs = structKeyExists( mongoClientOptions, "connectTimeout" ) ? javacast(
				"integer",
				mongoClientOptions.connectTimeout
			) : 3000;
			
			var clusterSettingsBuilder = jLoader.create( "com.mongodb.connection.ClusterSettings" ).builder();
			clusterSettingsBuilder.serverSelectionTimeout( timeoutMs, jLoader.create( "java.util.concurrent.TimeUnit" ).MILLISECONDS );
			builder.applyToClusterSettings( clusterSettingsBuilder.build() );
		}

		variables.conf.MongoClientSettings = builder.build();

		return variables.conf.MongoClientSettings;
	}

	private function readPreference( required string preference ){
		var rp = jLoader.create( "com.mongodb.ReadPreference" );

		switch ( preference ) {
			case "primary":
				return rp.primary();
				break;
			case "nearest":
				return rp.nearest();
				break;
			case "primaryPreferred":
				return rp.primaryPreferred();
				break;
			case "secondary":
				return rp.secondary();
				break;
			case "secondaryPreferred":
				return rp.secondaryPreferred();
				break;
			default:
				return rp.primary();
		}
	}

	private function readConcern( required string concern ){
		var rc = jLoader.create( "com.mongodb.ReadConcern" );
		return rc[ uCase( concern ) ];
	}

	private function writeConcern( required string concern ){
		var wc = jLoader.create( "com.mongodb.WriteConcern" );
		return wc[ uCase( concern ) ];
	}

	/**
	 * Main extension point: do whatever it takes to decide environment;
	 * set environment-specific defaults by overriding the environment-specific
	 * structure keyed on the environment name you decide
	 */
	public string function configureEnvironment(){
		// overriding classes could do all manner of interesting things here... read config from properties file, etc.
		return "local";
	}

	public string function getDBName(){
		return getDefaults().dbName;
	}

	public Array function getServers(){
		return getDefaults().servers;
	}

	public function getMongoClientOptions(){
		if ( not structKeyExists( getDefaults(), "mongoClientSettings" ) ) {
			buildMongoClientSettings( {} );
		}
		return getDefaults().mongoClientSettings;
	}

	public function getMongoClientSettings(){
		if ( not structKeyExists( getDefaults(), "mongoClientSettings" ) ) {
			buildMongoClientSettings( {} );
		}
		return getDefaults().mongoClientSettings;
	}

	public struct function getDefaults(){
		return conf;
	}

}
