/**
 *
 * Mongo Util
 *
 * The utility methods used to assist in correct typing of objects passed to the MongoDB driver
 *
 * @singleton
 * @package   cbmongodb.models.Mongo
 * @author    Jon Clausen <jon_clausen@silowebworks.com>
 * @license   Apache v2.0 <http: // www.apache.org / licenses/>
 */
component accessors="true" {

	property name="MongoConfig" inject="id:MongoConfig@cbmongodb";
	// property name="NullSupport" default="false";

	/**
	 *
	 * CBJavaloader
	 **/
	property name="jLoader" inject="id:loader@cbjavaloader";

	param name="nullSupport" default="false";

	/**
	 * Converts a ColdFusion structure to a CFBasicDBobject, which  the Java drivers can use
	 */
	function toMongo( any obj ){
		if ( !isStruct( arguments.obj ) && getMetadata( obj ).getCanonicalName() == "com.mongodb.CFBasicDBObject" ) {
			return obj;
		}
		if ( isArray( arguments.obj ) ) {
			var list = jLoader.create( "java.util.ArrayList" ).init();

			for ( var member in arguments.obj ) {
				list.add( toMongo( member ) );
			}

			return list;
		} else {
			return dbObjectnew( arguments.obj );
		}
	}

	function toMongoDocument( data ){
		var doc = jLoader.create( "org.bson.Document" ).init();

		data.keyArray().each( ( key, value ) => doc.put( key, value ) );

		if ( !structIsEmpty( data ) ) {
			ensureTyping( doc );
		}
		return doc;
	}

	/**
	 * Converts a Mongo DBObject to a ColdFusion structure
	 */
	function toCF( BasicDBObject ){
		if ( isNull( BasicDBObject ) ) return;

		// if we're in a loop iteration and the array item is simple, return it
		if ( isSimpleValue( BasicDBObject ) ) return BasicDbObject;

		if ( isArray( BasicDBObject ) ) {
			var cfObj = [];
			for ( var obj in BasicDBObject ) {
				arrayAppend( cfObj, toCF( obj ) );
			}
		} else {
			var cfObj = {};

			// structAppend(cfObj,BasicDBObject)
			try {
				cfObj.putAll( BasicDBObject );
			} catch ( any e ) {
				if ( getMetadata( BasicDBObject ).getName() == "org.bson.BsonUndefined" )
					return javacast( "null", "" );

				return BasicDBObject;
			}
			// loop our keys to ensure first-level items with sub-documents objects are converted
			for ( var key in cfObj ) {
				if ( !isNull( cfObj[ key ] ) && ( isArray( cfObj[ key ] ) || isStruct( cfObj[ key ] ) ) )
					cfObj[ key ] = toCF( cfObj[ key ] );
			}
		}

		// auto-stringify _id
		if ( isStruct( cfObj ) && structKeyExists( cfObj, "_id" ) && !isSimpleValue( cfObj[ "_id" ] ) ) {
			cfObj[ "_id" ] = cfObj[ "_id" ].toString();
		}

		return cfObj;
	}

	/**
	 * Convenience for turning a string _id into a Mongo ObjectId object
	 */
	function newObjectIDFromID( id ){
		if ( !isSimpleValue( id ) || !isObjectId( id ) ) return id;

		return jLoader.create( "org.bson.types.ObjectId" ).init( id );
	}

	/**
	 * Convenience for creating a new criteria object based on a string _id using modern Document
	 */
	function newIDCriteriaDocument( String id ){
		var doc = newDocument();
		doc.put( "_id", newObjectIDFromID( arguments.id ) );
		return doc;
	}

	/**
	 * Convenience for creating a new criteria object based on a string _id
	 * @deprecated Use newIDCriteriaDocument() instead for new code
	 */
	function newIDCriteriaObject( id ){
		var dbo = newDBObject();
		dbo.put( "_id", newObjectIDFromID( arguments.id ) );
		return dbo;
	}

	function isObjectId( id ){
		return jLoader.create( "org.bson.types.ObjectId" ).isValid( arguments.id );
	}

	/**
	 * Extracts the timestamp from the Doc's ObjectId. This represents the time the document was added to MongoDB
	 */
	function getDateFromDoc( doc ){
		var ts = doc[ "_id" ].getTime();
		return jLoader.create( "java.util.Date" ).init( ts );
	}

	/**
	 * Whether this doc is an instance of a CFMongoDB CFBasicDBObject
	 */
	function isCFBasicDBObject( doc ){
		return NOT isSimpleValue( doc ) && getMetadata( doc ).getCanonicalName() == "com.mongodb.CFBasicDBObject";
	}

	function isObjectIdString( required sId ){
		return (
			isSimpleValue( sId )
			&&
			!isNumeric( sId )
			&&
			left( trim( sId ), 1 ) != "$"
			&&
			arrayLen( sId.getBytes( "UTF-8" ) ) == 24
		);
	}


	/**
	 * Create a new instance of the Document. This is the modern way to create MongoDB documents.
	 */
	function newDocument(){
		return jLoader.create( "org.bson.Document" ).init();
	}

	/**
	 * Create a new instance of the CFBasicDBObject. You use these anywhere the Mongo Java driver takes a DBObject
	 * @deprecated Use newDocument() instead for new code
	 */
	function newDBObject(){
		return jLoader.create( "com.mongodb.BasicDBObject" ).init();
	}

	function dbObjectNew( contents ){
		var dbo = newDBObject();

		// toMongoDocument( arguments.contents ).entrySet().forEach( ( item ) => dbo.put( item.getKey(), item.getValue() ) );
		// this currently fails on boxlang

		// This dumps String: Document{{}}

		// this errors
		dbo.putAll( toMongoDocument( arguments.contents ) );

		if ( !isStruct( dbo ) && listLen( structKeyList( dbo ) ) > 0 ) {
			ensureTyping( dbo );
		}
		return dbo;
	}

	function ensureTyping( required dbo ){
		for ( var i in dbo ) {
			if ( !isNull( dbo[ i ] ) ) {
				if ( isArray( dbo[ i ] ) ) {
					ensureTypesInArray( dbo[ i ] );
				} else if ( isStruct( dbo[ i ] ) ) {
					ensureTyping( dbo[ i ] );
				} else if ( !isNumeric( dbo[ i ] ) && len( dbo[ i ] ) != 0 && isBoolean( dbo[ i ] ) ) {
					dbo.put( i, javacast( "boolean", dbo[ i ] ) );
				} else if ( isDate( dbo[ i ] ) ) {
					var dateObj = parseDateTime( dbo[ i ] );
					dbo.put( i, server.keyExists( "boxlang" ) ? dateObj.toDate() : dateObj );
				} else if ( NullSupport && isSimpleValue( dbo[ i ] ) && len( dbo[ i ] ) == 0 ) {
					dbo.put( i, javacast( "null", 0 ) );
				} else if ( i == "_id" && isObjectIdString( dbo[ i ] ) ) {
					dbo.put( i, newObjectIDFromID( dbo[ i ] ) );
				}
			} else if ( nullSupport && isSimpleValue( dbo[ i ] ) && len( dbo[ i ] ) eq 0 ) {
				dbo.put( i, javacast( "null", "" ) );
			}
		}

		// Hack
		// CF11 add two keys which break indexing  (Empty,PartialObject)
		try {
			dbo.remove( "Empty" );
		} catch ( Any e ) {
		}

		try {
			dbo.remove( "PartialObject" );
		} catch ( Any e ) {
		}
	}

	function ensureTypesInArray( required dboArray ){
		for ( var dbo in dboArray ) {
			if ( isStruct( dbo ) ) ensureTyping( dbo );
		}
	}

	function encapsulateDBResult( dbResult ){
		var enc = {};

		enc[ "getResult" ] = function(){
			return dbResult;
		};
		enc[ "asCursor" ] = function(){
			return dbResult.iterator();
		};
		enc[ "asArray" ] = function( stringify = false ){
			return this.asArray( dbResult, stringify );
		};
		enc[ "forEach" ] = function( required fn ){
			return dbResult.forEach( fn );
		};
		enc[ "asJSON" ] = function(){
			return serializeJSON( this.asArray( dbResult, true ) );
		};

		return enc;
	}

	/**
	 * Returns the results of a dbResult object as an array of documents
	 */
	function asArray( dbResult ){
		return toCF( dbResult.into( jLoader.create( "java.util.ArrayList" ).init() ) );
	}

	/**
	 * Indexing Utilities
	 */
	function createIndexOptions( options ){
		var idxOptions = jLoader.create( "com.mongodb.client.model.IndexOptions" ).init();

		if ( structKeyExists( options, "name" ) ) idxOptions.name( options.name );
		if ( structKeyExists( options, "sparse" ) ) idxOptions.sparse( options.sparse );
		if ( structKeyExists( options, "background" ) ) idxOptions.background( options.background );
		if ( structKeyExists( options, "unique" ) ) idxOptions.unique( options.unique );

		return idxOptions;
	}

	/**
	 * SQL to Mongo translated ordering statements
	 */
	numeric function mapOrder( required order ){
		var map = { "asc" : 1, "desc" : -1 };

		if ( isNumeric( arguments.order ) ) {
			return arguments.order;
		} else if ( structKeyExists( map, lCase( arguments.order ) ) ) {
			// FIXME?
			return javacast( "int", map[ lCase( arguments.order ) ] );
		} else {
			return map.asc;
		}
	}

	// Utility Methods Not Currently In Use
	/*
	 Creates a Mongo CFBasicDBObject whose order matches the order of the keyValues argument
	  keyValues can be:
	  	1) a string in k,k format: "STATUS,TS". This will set the value for each key to "1". Useful for creating Mongo's 'all true' structs, like the "keys" argument to group()
	    2) a string in k=v format: STATUS=1,TS=-1
		3) an array of strings in k=v format: ["STATUS=1","TS=-1"]
		4) an array of structs (often necessary when creating "command" objects for passing to db.command()):
		  createOrderedDBObject( [ {"mapreduce"="tasks"}, {"map"=map}, {"reduce"=reduce} ] )
	*/
	function createOrderedDBObject( keyValues, dbObject = "" ){
		if ( isSimpleValue( dbObject ) ) {
			dbObject = newDBObject();
		}

		var kv = "";

		if ( isSimpleValue( keyValues ) ) {
			keyValues = listToArray( keyValues );
		}

		for ( kv in keyValues ) {
			if ( isSimpleValue( kv ) ) {
				var key   = listFirst( kv, "=" );
				var value = find( "=", kv ) ? listRest( kv, "=" ) : 1;
			} else {
				var key   = structKeyList( kv );
				var value = kv[ key ];
			}
			dbObject[ key ] = value;
		}

		return dbObject;
	}

	function listToStruct( list ){
		var item      = "";
		var s         = {};
		var i         = 1;
		var items     = listToArray( list );
		var itemCount = arrayLen( items );

		for ( i; i lte itemCount; i++ ) {
			s.put( items[ i ], 1 );
		}

		return s;
	}

}
