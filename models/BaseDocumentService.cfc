/**
 *
 * Core MongoDB Document Service
 *
 * @package   cbmongodb.models
 * @author    Jon Clausen <jon_clausen@silowebworks.com>
 * @license   Apache v2.0 <http: // www.apache.org / licenses/>
 * @attribute string database 		The database to connect to.  If omitted, the database specified in the hosts config will be used. NOTE:Authentication credentials must match the server-level auth config.
 * @attribute string collection 		The name of the collection that the entity should map to
 */
component
	name      ="BaseDocumentService"
	database  ="test"
	collection="default"
	accessors ="true"
{

	/**
	 * Injected Properties
	 **/
	/**
	 * The Application Wirebox IOC Instance
	 **/
	property name="wirebox" inject="wirebox";

	/**
	 * The LogBox Logger for this Entity
	 **/
	property name="logbox" inject="logbox:logger:{this}";

	/**
	 *  The Coldbox Application Setttings Structure
	 **/
	property name="appSettings";

	/**
	 * The MongoDB Client
	 **/
	property name="MongoClient" inject="id:MongoClient@cbmongodb";

	/**
	 * The Mongo Utilities Library
	 **/
	property name="MongoUtil" inject="id:MongoUtil@cbmongodb";

	/**
	 * The Mongo Indexer Object
	 **/
	property name="MongoIndexer" inject="id:MongoIndexer@cbmongodb";

	/**
	 * The database client w/o a specified collection
	 **/
	property name="db";

	/**
	 * This key is maintained for backward compatibility but is marked as deprecated.
	 * You should use the component attribute method to declare your collection name.
	 *
	 * @deprecated
	 **/
	property name="collection" default="default";

	/**
	 * The instatiated database collection to perform operations on
	 **/
	property name="dbInstance";

	/**
	 * The container for the default document
	 **/
	property name="_default_document";

	/**
	 * package container for the active document entity
	 **/
	property name="_document";

	/**
	 * The id of the loaded document
	 **/
	property name="_id";

	/**
	 * package container for the loaded document before modifications
	 **/
	property name="_existing";

	/**
	 * Validation structure
	 *
	 * @example property name="myfield" schema=true validate="string";
	 **/
	property name="_validation";

	/**
	 * The schema map which will be persisted for validation and typing
	 **/
	property name="_map";

	/**
	 * Constructor
	 **/
	any function init(){
		var meta = getMetadata( this );

		if ( structKeyExists( meta, "collection" ) ) {
			this.collectionName = trim( meta.collection );
		} else if ( structKeyExists( variables, "collection" ) ) {
			this.collectionName = variables.collection;
		} else {
			throw( "Could not connect to MongoDB.  No Collection property or component attribute exists." );
		}

		/**
		 * Backward compatibility
		 *
		 * @deprecated
		 **/
		setCollection( this.collectionName );


		/**
		 *
		 *  Make sure our injected properties exist
		 **/
		if ( isNull( getWirebox() ) and structKeyExists( application, "wirebox" ) ) {
			application.wirebox.autowire( target = this, targetID = getMetadata( this ).name );
		} else if ( isNull( getWirebox() ) and structKeyExists( application, "cbController" ) ) {
			application.cbController.getWirebox().autowire( this );
		} else {
			throw( "Wirebox IOC Injection is required to use this service" );
		}

		this.setMongoUtil( getMongoClient().getMongoUtil() );
		this.setAppSettings( getWirebox().getBinder().getProperties() );

		// Connect to Mongo
		this.setDb( this.getMongoClient() );

		// If we have a database attribute
		if ( structKeyExists( meta, "database" ) ) {
			this.setDbInstance( this.getDb().getDBCollection( this.collectionName, trim( meta.database ) ) );
		} else {
			this.setDbInstance( this.getDb().getDBCollection( this.collectionName ) );
		}

		// Default Document Creation
		this.set_document( structNew() );

		this.set_default_document( structNew() );

		this.set_map( structNew() );

		this.detect();

		return this;
	}

	/*********************** INSTANTIATION AND OPTIMIZATION **********************/
	/**
	 * Evaluate our properties for the default document
	 */
	any function detect(){
		var properties         = getMetadata( this ).properties;
		var combinedProperties = [];

		// add our extended properties in case there are schema items
		if (
			structKeyExists( getMetadata( this ), "extends" ) && structKeyExists(
				getMetadata( this ).extends,
				"properties"
			)
		) {
			var extendedProperties = getMetadata( this ).extends.properties;
			// arrayAppend(properties,extendedProperties,true);

			for ( var i = 1; i <= arrayLen( properties ); i++ ) {
				arrayAppend( combinedProperties, properties[ i ] );
			}

			for ( var i = 1; i <= arrayLen( extendedProperties ); i++ ) {
				arrayAppend( combinedProperties, extendedProperties[ i ] );
			}
		}

		for ( var prop in combinedProperties ) {
			if ( structKeyExists( prop, "schema" ) && prop.schema ) {
				try {
					// add the property to your our map
					structAppend(
						this.get_map(),
						{
							"#structKeyExists( prop, "parent" ) ? prop.parent & "." & prop.name : prop.name#" : prop
						},
						true
					);

					generateSchemaAccessors( prop );

					if ( structKeyExists( prop, "parent" ) ) {
						// Test for doubling up on our parent attribute and dot notation
						var prop_name = listToArray( prop.name, "." );
						if ( prop_name[ 1 ] EQ prop.parent ) {
							throw( "IllegalAttributeException: The parent attribute &quot;" & prop.parent & "&quot; has been been duplicated in <strong>" & getMetadata(
								this
							).name & "</strong>. Use either dot notation for your property name or specify a parent attribute." )
						}

						// TODO: add upstream introspection to handle infinite nesting
						this.set( prop.parent & "." & prop.name, this.getPropertyDefault( prop ) );
					} else {
						this.set( prop.name, this.getPropertyDefault( prop ) );
					}

					// test for index values
					if ( structKeyExists( prop, "index" ) ) {
						this.applyIndex( prop, combinedProperties );
					}
				} catch ( any error ) {
					throw( "An error ocurred while attempting to instantiate #prop.name#.  The cause of the exception was #error.message#" );
				}
			}
		}

		this.set_default_document( structCopy( this.get_document() ) );
	}


	/********************************* INDEXING **************************************/
	/**
	 * Create and apply our indexes
	 *
	 * @param struct prop - the component property structure
	 * @param struct properties - the full properties structure (required if prop contains and "indexwith" attribute)
	 **/
	public function applyIndex( required prop, properties = [] ){
		arguments[ "dbInstance" ] = this.getDbInstance();

		return MongoIndexer.applyIndex( argumentCollection = arguments );
	}

	/********************************** SETTERS ***********************************/
	void function generateSchemaAccessors( required struct prop ){
		var properties       = getMetadata( this ).properties;
		var varSafeSeparator = "_";

		// now create var safe accessors
		// camel case our accessor
		var propName = replace( prop.name, ".", " ", "ALL" );
		propName     = reReplace( propName, "\b(\S)(\S*)\b", "\u\1\L\2", "all" );

		// now replace our delimiter with a var safe delimiter
		var accessorSuffix = replace( propName, " ", varSafeSeparator, "ALL" );

		// we need this to make sure a property name doesn't override a top level function or overload
		if ( !hasExistingAccessor( accessorSuffix ) ) {
			// first clear our existing accessors
			structDelete( this, "get" & prop.name );
			structDelete( this, "set" & prop.name );

			this[ "get" & accessorSuffix ] = function(){
				return locate( prop.name );
			};
			variables[ "get" & accessorSuffix ] = this[ "get" & accessorSuffix ];
			this[ "set" & accessorSuffix ]      = function( required value ){
				return this.set( prop.name, arguments.value );
			};
			variables[ "set" & accessorSuffix ] = this[ "set" & accessorSuffix ];
		}
	}

	boolean function hasExistingAccessor( required string suffix ){
		if ( structKeyExists( getMetadata( this ), "functions" ) ) {
			var functions = getMetadata( this ).functions;
		} else {
			functions = [];
		}
		if ( arrayContains( functions, "set" & suffix ) || arrayContains( functions, "get" & suffix ) ) {
			return true;
		} else {
			return false;
		}
	}

	/**
	 * Populate the document object with a structure
	 */
	any function populate( required struct document ){
		for ( var prop in ARGUMENTS.document ) {
			if ( !isNull( locate( prop ) ) ) {
				if ( isStruct( ARGUMENTS.document[ prop ] ) ) {
					var existing = this.locate( prop );
					structAppend( ARGUMENTS.document[ prop ], existing, false );
				}

				this.set( prop, ARGUMENTS.document[ prop ] );

				// normalize data
				if ( isNormalizationKey( prop ) ) {
					normalizeOn( prop );
				}
			}
		}
		return this;
	}

	/**
	 * Sets a document property
	 */
	any function set( required key, required value ){
		var doc  = this.get_document();
		var sget = "doc";
		var nest = listToArray( getDocumentPath( arguments.key ), "." );

		// handle top level struct containers which may be out of sequence in our property array
		if ( arrayLen( nest ) == 1 && isStruct( value ) && structIsEmpty( value ) ) {
			if ( !structKeyExists( doc, nest[ 1 ] ) ) {
				doc[ nest[ 1 ] ] = arguments.value;
			}
		} else {
			for ( var i = 1; i LT arrayLen( nest ); i = i + 1 ) {
				sget = sget & "." & nest[ i ];
			}

			// cf11 return empty not structure notation
			var nested = structGet( sget );

			if ( !isStruct( nested ) ) {
				nested = {};
			}
			nested[ nest[ arrayLen( nest ) ] ] = arguments.value;
		}

		this.entity( this.get_document() );

		// normalize data after we've scoped our entity
		if ( isSimpleValue( arguments.value ) && len( arguments.value ) && isNormalizationKey( arguments.key ) ) {
			normalizeOn( arguments.key );
		}

		return this;
	}

	/**
	 * Appends to an existing array schema property
	 **/
	any function append( required string key, required any value ){
		var doc  = this.get_document();
		var sget = "doc";
		var nest = listToArray( key, "." );

		for ( var i = 1; i LT arrayLen( nest ); i = i + 1 ) {
			sget = sget & "." & nest[ i ];
		}

		var nested = structGet( sget );

		if ( !isArray( nested[ nest[ arrayLen( nest ) ] ] ) ) throw( "Schema field #key# is not a valid array." );

		arrayAppend( nested[ nest[ arrayLen( nest ) ] ], value );

		this.entity( this.get_document() );
		return this;
	}

	/**
	 * Prepends to an existing array property
	 **/
	any function prepend( required string key, required any value ){
		var doc  = this.get_document();
		var sget = "doc";
		var nest = listToArray( key, "." );

		for ( var i = 1; i LT arrayLen( nest ); i = i + 1 ) {
			sget = sget & "." & nest[ i ];
		}

		var nested = structGet( sget );

		if ( !isArray( nested[ nest[ arrayLen( nest ) ] ] ) ) throw( "Schema field #key# is not a valid array." );

		arrayPrepend( nested[ nest[ arrayLen( nest ) ] ], value );

		this.entity( this.get_document() );
		return this;
	}

	/**
	 * Alias for get()
	 **/
	any function load( required _id, returnInstance = true ){
		this.reset();
		return this.get( arguments._id, arguments.returnInstance );
	}

	/**
	 * Load a record by _id
	 *
	 * @param _id - the _id value of the document
	 * @param boolean returnInstance - whether to return a loaded instance (true) or a result struct (false)
	 **/
	any function get( required _id, returnInstance = true ){
		var results = this.getDBInstance().findById( _id );

		if ( !isNull( results ) ) this.entity( results );

		if ( !isNull( results ) && !returnInstance ) {
			return results;
		} else {
			return this;
		}
	}

	/**
	 * Returns a CFML copy of the loaded document
	 **/
	struct function getDocument(){
		return getMongoUtil().toCF( this.get_document() );
	}

	/**
	 * Utility facade for getDocument()
	 **/
	struct function asStruct(){
		return this.getDocument();
	}

	/**
	 * Deletes a document by ID
	 **/
	any function delete( required _id ){
		var deleted = this.getDBInstance().deleteOne( getMongoUtil().newIDCriteriaObject( arguments[ "_id" ] ) );

		return deleted.wasAcknowledged();
	}


	/**
	 * reset the document state
	 *
	 * @chainable
	 **/
	any function reset(){
		this.evict();
		return this;
	}

	/**
	 * Evicts the document entity and clears the query arguments
	 **/
	any function evict(){
		structDelete( variables, "_id" );

		this.set_document( structCopy( this.get_default_document() ) );
		this.set_existing( structCopy( this.get_document() ) );
	}

	/*********************** Auto Normalization Methods **********************/


	/**
	 * Determines whether a property is a normalization key for another property
	 *
	 * @param string key 		The property name
	 **/
	boolean function isNormalizationKey( required string key ){
		var normalizationFields = structFindValue( get_map(), key, "ALL" );
		for ( var found in normalizationFields ) {
			var mapping = found.owner;
			if ( structKeyExists( mapping, "normalize" ) && structKeyExists( mapping, "on" ) && mapping.on == key )
				return true;
		}
		return false;
	}

	/**
	 * Returns the normalized data for a normalization key
	 *
	 * @param string key 	The normalization key property name
	 */
	any function getNormalizedData( required string key ){
		var normalizationFields = structFindValue( get_map(), arguments.key, "ALL" );

		for ( var found in normalizationFields ) {
			var mapping = found.owner;
			if (
				structKeyExists( mapping, "normalize" ) && structKeyExists( mapping, "on" ) && mapping.on == key && !isNull(
					locate( mapping.on )
				)
			) {
				var normalizationMap = mapping;
				var normTarget       = Wirebox.getInstance( mapping.normalize ).load( locate( mapping.on ) );
				if ( normTarget.loaded() ) {
					// assemble specified keys, if available
					if ( structKeyExists( mapping, "keys" ) ) {
						var normalizedData = {};
						for ( var normKey in listToArray( mapping.keys ) ) {
							// handle nulls as empty strings
							var normData              = normTarget.locate( normKey );
							normalizedData[ normKey ] = !isNull( normData ) ? normData : "";
						}
						return normalizedData;
					} else {
						return normTarget.getDocument();
					}
				} else {
					throw( "Normalization data for the property #mapping.name# could not be loaded as a record matching the #mapping.normalize# property value of #locate( mapping.on )# could not be found in the database." )
				}
			}
		}

		// return a null default
		return javacast( "null", 0 );
	}

	/**
	 * Processes auto-normalization of a field
	 *
	 * @param string key 	The normalization key property name
	 **/
	any function normalizeOn( required string key ){
		var normalizationFields = structFindValue( get_map(), key, "ALL" );

		for ( var found in normalizationFields ) {
			var mapping = found.owner;
			if ( structKeyExists( mapping, "normalize" ) && structKeyExists( mapping, "on" ) && mapping.on == key ) {
				var normalizationMapping = mapping;
				break;
			}
		}

		if ( !isNull( normalizationMapping ) ) {
			var farData = getNormalizedData( arguments.key );

			if ( isNull( farData ) )
				throw( "Normalized data could not be found for model #getMetadata( this ).name# on key #arguments.key#" );

			var nearData = locate( normalizationMapping.name );

			if ( isStruct( nearData ) ) {
				structAppend( nearData, farData, true );
			} else {
				nearData = farData;
			}

			if ( !isNull( normData ) ) {
				this.set( normalizationMapping.name, nearData );
			}
		}

		return;
	}


	/********************************* Document Object Location, Searching and Query Utils ****************************************/

	void function criteria( struct criteria ){
		if ( structKeyExists( arguments.criteria, "_id" ) ) {
			// exclude our nested query obects
			if ( !isStruct( arguments.criteria[ "_id" ] ) && isSimpleValue( arguments.criteria[ "_id" ] ) )
				arguments.criteria[ "_id" ] = getMongoUtil().newObjectIDfromID( arguments.criteria[ "_id" ] );
		}

		this.set_criteria( arguments.criteria );
	}

	/**
	 * Helper function to locate deeply nested document items
	 *
	 * @param key the key to locate
	 * @usage locate('key.subkey.subsubkey.waydowndeepsubkey')
	 *
	 * @return any the value of the key or null if the key is not found
	 **/
	any function locate( string key ){
		var document = this.get_document();

		// if we have an existing document key with that name, return it
		if ( structKeyExists( document, ARGUMENTS.key ) ) {
			return document[ ARGUMENTS.key ];
		} else {
			var keyName = getDocumentPath( ARGUMENTS.key );
			if ( isDefined( "document.#keyName#" ) ) {
				return evaluate( "document.#keyName#" );
			}
		}

		return;
	}


	/**
	 * Returns the document path for a given property name or key
	 *
	 * @param string key 	The property name
	 */
	string function getDocumentPath( required string key ){
		if ( structKeyExists( get_default_document(), ARGUMENTS.key ) ) return ARGUMENTS.key;

		var mappings     = structFindValue( get_map(), ARGUMENTS.key, "ALL" );
		var documentPath = ARGUMENTS.key;
		for ( var map in mappings ) {
			if ( structKeyExists( map.owner, "parent" ) && map.owner.name == ARGUMENTS.key ) {
				documentPath = map.owner.parent & "." & ARGUMENTS.key;
			}
		}

		return documentPath;
	}

	/**
	 * Returns the default property value
	 *
	 * Used to populate the document defaults
	 */
	any function getPropertyDefault( prop ){
		var empty_string = "";
		if ( structKeyExists( prop, "default" ) ) {
			if ( structKeyExists( prop, "validate" ) ) {
				switch ( prop.validate ) {
					case "boolean":
						return javacast( "boolean", prop.default );
					default:
						return prop.default;
				}
			} else {
				return prop.default;
			}
		} else if ( structKeyExists( prop, "validate" ) ) {
			switch ( prop.validate ) {
				case "string":
					return empty_string;
				case "numeric":
				case "float":
				case "integer":
					return 0;
				case "array":
					return arrayNew( 1 );
				case "struct":
					return structNew();
				default:
					break;
			}
		}
		return empty_string;
	}

	/**
	 * Handles correct formatting of geoJSON objects
	 *
	 * @param array coordinates - an array of coordinates (e.g.: [-85.570381,42.9130449])
	 * @param array [type="Point"] - the geometry type < http://docs.mongodb.org/manual/core/2dsphere/#geojson-objects >
	 */
	any function toGeoJSON( array coordinates, string type = "Point" ){
		var geo = {
			"type"        : arguments.type,
			"coordinates" : arguments.coordinates
		};
		// serializing and deserializing ensures our quoted keys remain intact in transmission

		return ( deserializeJSON( serializeJSON( geo ) ) );
	}

	/**
	 * SQL to Mongo ordering translations
	 */
	numeric function mapOrder( required order ){
		return getMongoUtil().mapOrder( argumentCollection = arguments );
	}

	/**
	 * Returns the Mongo.Collection object for advanced operations
	 * facade for getDBInstance()
	 */
	any function getCollectionObject(){
		return this.getDBInstance();
	}

	/**
	 * facade for Mongo.Util.toMongo
	 *
	 * @param mixed arg 		The struct or array to convert to a Mongo DBObject
	 */
	any function toMongo( required arg ){
		return getMongoUtil().toMongo( arg );
	}

	/**
	 * facade for Mongo.Util.toMongoDocument
	 *
	 * @param struct arg 	The struct to convert to a MongoDB Document Object
	 */
	any function toMongoDocument( required struct arg ){
		return getMongoUtil().toMongoDocument( arg );
	}

}
