/**
*
* Mongo Config
*
* The configuration object passed to MongoDB
*
* @singleton
* @package cbmongodb.models.Mongo
* @author Jon Clausen <jon_clausen@silowebworks.com>
* @license Apache v2.0 <http://www.apache.org/licenses/>
* 
*/
component accessors="true" output="false" hint="Main configuration for MongoDB Connections"{
	/**
	* CBJavaloader
	**/
	property name="jLoader" inject="id:loader@cbjavaloader";
	property name="configStruct";

	variables.conf = {};


	/**
	* Constructor
	* @hosts Defaults to [{serverName='localhost',serverPort='27017'}]
	*/
	public function init(configStruct){
	 	setConfigStruct(arguments.configStruct);

	 	return this;
	}

	/**
	* After init the autowire properties
	*/
	public function onDIComplete(){
		if(isNull(jLoader)){
			application.wirebox.autowire(this);
		}
		var srvString = "";
		var host = configStruct.host;
		var dbName = configStruct.db; 
		var MongoClientOptions = structKeyExists(configStruct,'clientOptions')?configStruct.clientOptions:{};
		var auth = {
			serverName = host.servername,
			username = host.username,
			password = host.password,
			db = host.authenticationDB
		};

		srvString = "mongodb+srv://" & auth.username & ":" & auth.password & "@" & host.serverName & "/" & auth.db;

		if( !structIsEmpty(MongoClientOptions)) {
			srvString &= "?";
			var optionCount = structCount(MongoClientOptions);
			var index = 1;
			for( var option in MongoClientOptions ) {
				srvString &= option & "=" & MongoClientOptions[option];
				if( index != optionCount ) {
					srvString &= "&";
				}
				index ++;
			}
		}
		variables.conf = { 
			dbname = dbName, 
			clientUri = jLoader.create("com.mongodb.MongoClientURI").init( srvString )
		};
		
		//main entry point for environment-aware configuration; subclasses should do their work in here
		environment = configureEnvironment();

		return this;
	}

	public function addServer(serverName, serverPort){
		var sa = jLoader.create("com.mongodb.ServerAddress").init( serverName, serverPort );
		variables.conf.servers.add( sa );
		
		return this;
	}

	public function removeAllServers(){
		variables.conf.servers.clear();
		
		return this;
	}

	function buildMongoClientOptions( struct mongoClientOptions ){
		var builder = jLoader.create("com.mongodb.MongoClientOptions$Builder");

		for( var key in mongoClientOptions ){
			var arg = mongoClientOptions[key];
			try{
				switch(key){
					case "readPreference":
						var rp = this.readPreference(arg);
						builder.readPreference(rp);
						break;

					case "readConcern":
						var rc = this.readConcern(arg);
						builder.readConcern(rc);
						break;

					case "writeConcern":
						var wc = this.writeConcern(arg);
						builder.writeConcern(wc);
						break;

					default:
						evaluate("builder.#key#( arg )");
				}
			} catch (any e){
				//writeDump(var=e,top=1);
				//abort;
				throw (message="The Mongo Client option #key# could not be found.  Please verify your clientOptions settings contain only valid MongoClientOptions settings: http://api.mongodb.org/java/current/com/mongodb/MongoClientOptions.Builder.html");
			}
		}

		//Set our server selection timeout to our connect timeout if it's not specified - this prevents auth failures from taking 30000ms to return the error
		if(!structKeyExists(mongoClientOptions,'serverSelectionTimeout')){
			builder.serverSelectionTimeout(structKeyExists(mongoClientOptions,'connectTimeout')?mongoClientOptions.connectTimeout:3000);
		}

		variables.conf.MongoClientOptions = builder.build();

		return variables.conf.MongoClientOptions;
	}

	private function readPreference(required string preference){
		var rp = jLoader.create('com.mongodb.ReadPreference');

		switch(preference){
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

	private function readConcern(required string concern){
		var rc = jLoader.create('com.mongodb.ReadConcern');
		return rc[uCase(concern)];
	}

	private function writeConcern(required string concern){
		var wc = jLoader.create('com.mongodb.WriteConcern');
		return wc[uCase(concern)];
	}

	/**
	* Main extension point: do whatever it takes to decide environment;
	* set environment-specific defaults by overriding the environment-specific
	* structure keyed on the environment name you decide
	*/
	public string function configureEnvironment(){
		//overriding classes could do all manner of interesting things here... read config from properties file, etc.
		return "local";
	}

	public string function getDBName(){ 
		return getDefaults().dbName; 
	}

	public Array function getServers(){
		return getDefaults().servers; 
	}

	public function getMongoClientOptions(){
		if( not structKeyExists(getDefaults(), "mongoClientOptions") ){
			buildMongoClientOptions({});
		}
		return getDefaults().mongoClientOptions;
	}

	public struct function getDefaults(){ 
	 	return conf; 
	}

}
