/**
 *
 * Mongo Collection
 *
 * The collection interface used for client operations by CBMongodb. Handles the translation of CFML objects for the DBCollection instance.
 *
 * @constructor init(java:com.mongodb.MongoCollectionImpl)
 * @package     cbmongodb.models.Mongo
 * @author      Jon Clausen <jon_clausen@silowebworks.com>
 * @license     Apache v2.0 <http: // www.apache.org / licenses/>
 */
component accessors="true" {

	/**
	 * Mongo Utils
	 **/
	property name="MongoUtil" inject="id:MongoUtil@cbmongodb";
	/**
	 * CBJavaloader
	 **/
	property name="jLoader" inject="id:loader@cbjavaloader";
	/**
	 * The native java Collection Object
	 **/
	property name="dbCollection";
	/**
	 * The name of our collection
	 **/
	property name="collectionName";

	/**
	 * Constructor - Must be manually instantiated with the Mongo Collection Object
	 *
	 * @param java:com.mongodb.MongoCollectionImpl dbCollection 	The MongoDB Collection Object
	 */
	public function init( dbCollectionInstance ){
		// if, for some reason, we need to instantiate manually
		// if(isNull(MongoUtil)) application.wirebox.autowire(this);

		variables.dbCollection   = arguments.dbCollectionInstance;
		// add an immutability testing property
		variables.collectionName = getDbCollection().getNamespace().getCollectionName();

		return this;
	}

	function onDIComplete(){
		return this;
	}

	/**
	 * ====================================
	 * Basic Collection Operational Methods
	 * ====================================
	 **/

	/**
	 * Drops the collection
	 **/
	public function drop(){
		return getDBCollection().drop();
	}

	/**
	 * ====================================
	 * Collection Count/Find Methods
	 * ====================================
	 **/

	/**
	 * Counts the number of records, by restriction or in total
	 *
	 * @param struct [criteria]	A criteria struct which restricts the counted document
	 */
	public function count( criteria = {} ){
		var mongoCriteria = getMongoUtil().toMongo( arguments.criteria );
		var collection    = getDBCollection();
		return collection.countDocuments( mongoCriteria );
	}

	/**
	 * Facade for the drivers find method. Encapuslates the result with a number of utility methods
	 *
	 * @param struct [criteria]	The search criteria for the query
	 * @param struct [options] 	The options for the search (accepts: offset,limit, skip, projection)
	 */
	public function find( required criteria = {}, required struct options = {} ){
		var results = getDBCollection().find( getMongoUtil().toMongoDocument( arguments.criteria ) );

		if ( structKeyExists( options, "offset" ) ) results.skip( options.offset );
		if ( structKeyExists( options, "sort" ) ) results.sort( getMongoUtil().toMongoDocument( options.sort ) );
		if ( structKeyExists( options, "limit" ) && options.limit > 0 ) results.limit( options.limit );
		if ( structKeyExists( options, "projection" ) )
			results.projection( getMongoUtil().toMongo( options.projection ) );

		return getMongoUtil().encapsulateDBResult( results );
	}

	/**
	 * Finds a single document by its _id
	 *
	 * @param mixed id 				The id of the document to be retrieved - may be either a BSON object or string
	 *
	 * @return mixed result|null 	Returns the result if found or returns null if the document was not found
	 */
	public function findById( required id ){
		var qId = getMongoUtil().newIDCriteriaObject( arguments.id );

		var results     = this.find( qId ).asCursor();
		var firstResult = results.tryNext();
		results.close();

		if ( isNull( firstResult ) ) return;

		return getMongoUtil().toCF( firstResult );
	}



	/**
	 * Performs an aggregation operation on the collection using match or projection
	 * <br><br>See <a href="https://docs.mongodb.org/manual/aggregation/">https://docs.mongodb.org/manual/aggregation/</a> for more information and commands
	 *
	 * @param struct [criteria]		The criteria to match the aggregation results against
	 * @param struct group 			The group by operational command (e.g. {"_id":"$orderId","$sum":"amount"} where $orderId references the orderId key in the document)
	 * @param struct [projection] 	A projection to be used on items in the collection (e.g. {"name":{$toUpper:"$firstName"}})
	 * @param mixed sort 			A string or struct used to sort the results (e.g. "name" or {"name":-1}).  Must be included within the projection key name
	 * @param struct groupMatch      An additional match on the grouped values to append to the aggregation ( e.g. {"amount":{"$gte":100}} )
	 */
	public function aggregate(
		struct criteria,
		required struct group,
		struct projection,
		sort,
		groupMatch
	){
		if ( isNull( arguments.criteria ) and isNull( arguments.projection ) )
			throw(
				type    = "MissingArgumentException",
				message = "Neither a critera or projection argument were provided. For custom aggregations, please see the aggregation() method."
			);

		var proj = [];

		if ( !isNull( arguments.criteria ) ) {
			arrayAppend( proj, { "$match" : arguments.criteria } );
		}
		if ( !isNull( arguments.projection ) ) {
			arrayAppend( proj, { "$project" : arguments.projection } );
		}

		arrayAppend( proj, { "$group" : arguments.group } );

		if ( !isNull( arguments.groupMatch ) ) {
			arrayAppend( proj, { "$match" : arguments.groupMatch } );
		}

		if ( !isNull( arguments.sort ) ) {
			if ( isStruct( arguments.sort ) ) {
				arrayAppend( proj, { "$sort" : arguments.sort } );
			} else {
				arrayAppend( proj, { "$sort" : { "#arguments.sort#" : 1 } } );
			}
		}
		var agResult = getDbCollection().aggregate( toMongo( proj ) );

		return getMongoUtil().encapsulateDBResult( agResult );
	}

	public function aggregation( required array command ){
		var aggregate = getDbCollection().aggregate( toMongo( arguments.command ) );
		return getMongoUtil().encapsulateDBResult( aggregate );
	}

	/**
	 * Returns the list of distinct values for a specified field name
	 *
	 */
	public function distinct( required string fieldName, struct criteria = {} ){
		// FIXME: Not currently operational - casting issue?
		// var distinct = getDBCollection().distinct(arguments.fieldName,toMongo(arguments.criteria));

		return getMongoUtil().toCF( getDbCollection().distinct( argumentCollection = arguments ) );
	}


	/**
	 * Performs a Map-Reduce operation on the collection
	 * <br><br><a href="https://docs.mongodb.org/manual/core/map-reduce/">See Mongo Documentation for more information on Map-Reduce functionality</a>
	 *
	 * @param string map 		 The javascript map command <a href="https://docs.mongodb.org/manual/core/map-reduce/">Docs</a>
	 * @param string reduce 		 The javascript reduction command <a href="https://docs.mongodb.org/manual/core/map-reduce/">Docs</a>
	 */
	public function mapReduce( required string map, required string reduce ){
		var mr = getDbCollection().mapReduce( arguments.map, arguments.reduce );

		return getMongoUtil().encapsulateDBResult( mr );
	}

	/**
	 * ====================================
	 * Collection Document Creation Methods
	 * ====================================
	 **/

	/**
	 * Inserts a single document
	 *
	 * @param required struct document 	The document to be inserted
	 */
	public function insertOne( required document ){
		var doc = getMongoUtil().toMongoDocument( document );

		// our doc is updated by reference
		getDBCollection().insertOne( doc );

		return getMongoUtil().toCF( doc );
	}

	/**
	 * Inserts an array of document
	 *
	 * @param array docs 	An array of structs which are the documents to be inserted
	 */
	public function insertMany( required array docs ){
		var mongoDocs = jLoader.create( "java.util.ArrayList" );

		for ( var doc in docs ) {
			mongoDocs.add( toMongoDocument( doc ) );
		}

		getDbCollection().insertMany( mongoDocs );

		return getMongoUtil().toCF( mongoDocs );
	}

	/**
	 * Facade for the driver's bulkWrite() method
	 * <br><br><strong>NOTE:</strong> Not implemented as CF native at the present time. Operations will need to be performed using the java arguments: <a href="http://api.mongodb.org/java/current/com/mongodb/DBCollection.html">http://api.mongodb.org/java/current/com/mongodb/DBCollection.html</a>
	 **/
	public function bulkWrite(){
		return getDbCollection().bulkWrite( argumentCollection = arguments );
	}

	/**
	 * ====================================
	 * Collection Document Update Methods
	 * ====================================
	 **/

	/**
	 * Generic Save Function - Uses findOneAndReplace()
	 *
	 * @param struct document 		The document to be saved
	 * @param boolean upsert			Whether the document should be added if it cannot be found
	 */
	public function save( required document, required upsert = false ){
		var utils = getMongoUtil();

		if ( arguments.upsert and !structKeyExists( document, "_id" ) ) {
			var doc = insertOne( arguments.document );
		} else {
			var criteria = utils.newIDCriteriaObject( arguments.document[ "_id" ] );

			arguments.document[ "_id" ] = getMongoUtil().newObjectIdFromId( arguments.document[ "_id" ] );

			var doc = findOneAndReplace( criteria, arguments.document );
		}

		return getMongoUtil().toCF( doc );
	}

	/**
	 * Replaces one document found by a designated criteria
	 * <br><br><strong>NOTE:</strong> facade for findOneAndReplace()
	 *
	 * @param struct criteria 		The critera for replacement (e.g. {"_id":"123456789012456bx"})
	 * @param document 				The document which replaces the queried object
	 */
	public function replaceOne( required criteria, required document ){
		structAppend( arguments.document, arguments.criteria, true );

		return getMongoUtil().toCF( findOneAndReplace( argumentCollection = arguments ) );
	}

	/**
	 * Updates one document found by a designated criteria
	 * <br><br><strong>NOTE:</strong> facade for findOneAndUpdate()
	 *
	 * @param struct criteria 		The critera for update (e.g. {"_id":"123456789012456bx"})
	 * @param operation				The operational struct object which updates the queried object
	 */
	public function updateOne( required criteria, required operation ){
		return getMongoUtil().toCF( findOneandUpdate( argumentCollection = arguments ) );
	}

	/**
	 * Updates multiple documents found by a designated criteria
	 * <br><br><strong>NOTE:</strong> facade for findOneAndUpdate()
	 *
	 * @param struct criteria 		The critera for update (e.g. {"_id":"123456789012456bx"})
	 * @param operation 				The operational struct object which updates the queried object
	 */
	public function updateMany( required criteria, required operation ){
		return getDBCollection().updateMany( toMongo( arguments.criteria ), toMongo( operation ) );
	}

	/**
	 * Updates a single document found by a designated criteria
	 *
	 * @param struct criteria 		The critera for update (e.g. {"_id":"123456789012456bx"})
	 * @param operation 				The operational struct object which updates the queried object
	 */
	public function findOneAndUpdate( required criteria, required operation ){
		var updateOptions = jLoader.create( "com.mongodb.client.model.FindOneAndUpdateOptions" );
		updateOptions.returnDocument( jLoader.create( "com.mongodb.client.model.ReturnDocument" ).AFTER );

		return getMongoUtil().toCF(
			getDBCollection().findOneAndUpdate(
				toMongo( arguments.criteria ),
				toMongo( operation ),
				updateOptions
			)
		);
	}


	/**
	 * Finds a single document and replaces it
	 *
	 * @param struct criteria 		The critera for replacement (e.g. {"_id":"123456789012456bx"})
	 * @param document 				The document which replaces the queried object
	 */
	public function findOneAndReplace( required criteria, required document ){
		var utils = getMongoUtil();

		var search = utils.toMongo( arguments.criteria );

		var update = utils.toMongoDocument( arguments.document );

		var replaceOptions = jLoader.create( "com.mongodb.client.model.FindOneAndReplaceOptions" );
		replaceOptions.returnDocument( jLoader.create( "com.mongodb.client.model.ReturnDocument" ).AFTER );

		return getMongoUtil().toCF( this.getDBCollection().findOneAndReplace( search, update, replaceOptions ) );
	}

	/**
	 * ====================================
	 * Collection Document Deletion Methods
	 * ====================================
	 **/

	/**
	 * Finds one document and deletes it
	 *
	 * @param struct criteria 		The criteria for the deletion (e.g. {"_id":"123456789012456bx"})
	 * @param struct [options] 		Any options which should be applied to the deletion
	 */
	public function findOneAndDelete( required struct criteria, options ){
		if ( isNull( options ) ) {
			return getDBCollection().findOneAndDelete( getMongoUtil().toMongo( arguments.criteria ) );
		} else {
			return getDBCollection().findOneAndDelete(
				getMongoUtil().toMongo( arguments.criteria ),
				getMongoUtil().toMongo( options )
			);
		}
	}


	/**
	 * Utility method which emulates the remove() method available in the v2 Mongo java drivers
	 *
	 * @param struct criteria 		The criteria for the document deletion
	 * @param boolean multiple 		Whether to delete multiple records. Defaults to true
	 */
	public function remove( required criteria, multiple = true ){
		if ( arguments.multiple ) {
			var removed = deleteMany( arguments.criteria );
		} else {
			var removed = deleteOne( arguments.criteria );
		}
		return removed;
	}

	/**
	 * Deletes a single document by criteria
	 *
	 * @param struct criteria 		The critera for deletion (e.g. {"_id":"123456789012456bx"})
	 */
	public function deleteOne( required criteria ){
		return getDBCollection().deleteOne( getMongoUtil().toMongo( arguments.criteria ) );
	}

	/**
	 * Deletes many documents by criteria
	 *
	 * @param struct criteria 		The critera for deletion (e.g. {"created":{"$lt":now()}})
	 */
	public function deleteMany( required criteria = {} ){
		return getDBCollection().deleteMany( getMongoUtil().toMongo( arguments.criteria ) );
	}

	/**
	 * ====================================
	 * Collection Indexing Methods
	 * ====================================
	 **/

	/**
	 * Returns an array of object maps for all of the indexes in the collection
	 **/
	public function getIndexInfo(){
		var indexList = getDBCollection().listIndexes().iterator();
		var indexes   = [];
		while ( indexList.hasNext() ) {
			arrayAppend( indexes, indexList.next() );
		}
		return indexes;
	}

	/**
	 * Drops all indexes in a collection
	 **/
	public function dropIndexes(){
		return getDBCollection().dropIndexes();
	}

	/**
	 * Drops an index 		Either a name or a criteria to search the existing indexes may be specified
	 *
	 * @param string indexName
	 **/
	public function dropIndex( string indexName, criteria ){
		return getDbCollection().dropIndex( !isNull( indexName ) ? indexName : toMongo( criteria ) );
	}

	/**
	 * Creates a standard index
	 *
	 * @param struct operation 		The index operation, containing the keys to be indexed (e.g. {"lastname":-1,"firstname":1})
	 * @param struct options 		The indexing options such as the index name, sparse settings, etc.
	 */
	public function createIndex( required operation, required options = {} ){
		var idxOptions = getMongoUtil().createIndexOptions( options );

		try {
			this.getDBCollection().createIndex( toMongo( operation ), idxOptions );
		} catch ( any e ) {
			throw( "Index on #options[ "name" ]# could not be created.  The error returned was: <strong>#e.message#</strong>  #idxOptions.toString()#--doc:[#toMongo( operation ).toString()#]" );
		}
	}

	/**
	 * Creates a geospatial index
	 *
	 * @param string field 			The field to index
	 * @param struct options 		The indexing options such as the index name, sparse settings, etc.
	 * @param string	geoType 		The GEOJSON spatial type to apply for the index.  Defaults to '2dsphere'.
	 */
	public function createGeoIndex(
		required string field,
		required options        = {},
		required string geoType = "2dsphere"
	){
		var idxOptions = getMongoUtil().createIndexOptions( options );
		var doc        = { "#arguments.field#" : arguments.geoType };

		try {
			this.getDBCollection().createIndex( toMongo( doc ), idxOptions );
		} catch ( any e ) {
			throw( "Geo Index on #options[ "name" ]# could not be created.  The error returned was: <strong>#e.message#</strong> #idxOptions.toString()#--doc:[#toMongo( doc ).toString()#]" );
		}
	}

	/**
	 * Creates multiple indexes
	 *
	 * @param array indexes  	The array of index structs.  Each array item should contain the key "operation", with an optional "options" key.
	 */
	public function createIndexes( required array indexes ){
		for ( var idx in arguments.index ) {
			createIndex( argumentCollection = idx );
		}
	}


	/**
	 * ====================================
	 * Private Methods
	 * ====================================
	 **/

	/**
	 * Utility facade for Mongo.Util.toMongo
	 */
	private function toMongo( required obj ){
		return getMongoUtil().toMongo( arguments.obj );
	}

	/**
	 * Utility facade for Mongo.Util.toMongoDocument
	 */
	private function toMongoDocument( required doc ){
		return getMongoUtil().toMongoDocument( arguments.doc );
	}

}
