/**
 *
 * Active Entity for CBMongoDB
 *
 * allows you to enhance your usage of MongoDB with an Active Record pattern
 *
 * @package cbmongodb.models
 * @author  Jon Clausen <jon_clausen@silowebworks.com>
 * @license Apache v2.0 <http: // www.apache.org / licenses/>
 */

component
	name     ="CFMongoActiveEntity"
	extends  ="cbmongodb.models.BaseDocumentService"
	accessors="true"
{

	/**
	 * Default query arguments
	 */
	property name="_criteria";
	property name="_keys"   default="";
	property name="_offset" default=0;
	property name="_limit"  default=0;
	property name="_sort";
	property name="_operators";

	/**
	 * A separate collection to be queried
	 *
	 * As MongoDB doesn't support joins in the RDBMS fashion,
	 * we'll need to pass our active entity document objects rather than as comparisons
	 */
	property name="xCollection";

	/**
	 * The map reduction
	 */
	property name="xReduce";

	/**
	 * Virtual Entity Constructor ( if you override it, make sure you call super.init() )
	 */
	function init(){
		this.criteria( {} );
		this.set_sort( {} );
		// Valid operators for where() clauses
		this.set_operators( [ "=", "!=", ">=", "<=", "<>", "in", "like" ] );

		return super.init();
	}

	/************************************** PUBLIC *********************************************/

	/**
	 * The master query method
	 */
	any function query(
		struct criteria = get_criteria(),
		numeric offset  = variables._offset,
		numeric limit   = variables._limit,
		any sort        = variables._sort
	){
		var results = this
			.getDBInstance()
			.find(
				criteria,
				{
					"offset" : arguments.offset,
					"limit"  : arguments.limit,
					"sort"   : arguments.sort
				}
			);

		this.resetQuery();

		return results;
	}

	/**
	 * Map reduce query method
	 */
	any function mapReduce( required string map, required string reduce ){
		return getDbInstance().mapReduce( argumentCollection = arguments );
	}


	/**
	 * Save the current entity
	 *
	 * @param boolean upsert - insert the record if it does not exist
	 * @param boolean returnInstance - if passed as true, the loaded instance will be returned.  If false, the _id value will be returned.
	 * @param struct document - optionally pass a raw document to be saved
	 */
	any function save(
		required document,
		upsert         = false,
		returnInstance = false
	){
		var doc = getDbInstance().save( arguments.document, arguments.upsert );

		if ( arguments.upsert ) {
			this.evict().load( doc );
		}

		if ( arguments.returnInstance ) {
			return this;
		}

		return this.get_id();
	}

	/**
	 * Updates the loaded record
	 *
	 * Alias for save() with an explicit
	 *
	 * @param returnInstance whether to return the loaded instance
	 */
	any function update( returnInstance = false ){
		if ( !structKeyExists( VARIABLES, "ForceValidation" ) || !variables.ForceValidation || this.isValid() ) {
			return this.save( this.get_document() );
		} else {
			var errorMessage = "Document could not be inserted as it did not validate.  Errors: ";

			for ( var error in this.getValidationResults().errors ) {
				errorMessage = errorMessage & error.description & ", ";
			};

			throw( errorMessage );
		}
	}

	/**
	 * Creates
	 *
	 * @param boolean returnInstance - whether to return the loaded object. If false, the _id of the inserted record is returned
	 */
	any function create( returnInstance = false, required document = get_document() ){
		if ( this.loaded() )
			throw( "The create method may not be called on a loaded entity. Use the update() method to update an existing entity or reset the entity state" );

		if ( !structKeyExists( VARIABLES, "ForceValidation" ) || !variables.ForceValidation || this.isValid() ) {
			var doc = getDbInstance().insertOne( arguments.document );

			this.set_document( doc );

			this.set_id( doc[ "_id" ] );

			if ( arguments.returnInstance ) return this;

			return this.get_id().toString();
		} else {
			var errorMessage = "Document could not be inserted as it did not validate.  Errors: ";
			for ( var error in this.getValidationResults().errors ) {
				errorMessage &= error.description & ", ";
			};
			throw( errorMessage );
		}
	}

	/**
	 * CBMongoDB where clause equivalent.  Appends query criteria to an ongoing query build
	 *
	 * @param string key 		The key to be queried
	 * @param mixed 	operator 	When passed as a valid operator, an operational query will be assembled.  When the value is not match to an operator, an "equals" criteria will be appended
	 * @param string [value] 	If a valid operator is passed, the value would provide the operational comparison
	 */
	any function where( key, any operator = "=", any value ){
		if ( isStruct( ARGUMENTS.key ) ) return this.appendCriteria( ARGUMENTS.key );

		if ( !arrayFind( this.get_operators(), operator ) ) {
			return this.where( key = key, value = operator );
		} else {
			if ( key == "_id" ) ARGUMENTS.value = getMongoUtil().newObjectIdFromId( ARGUMENTS.value );
			var criteria = this.get_criteria();
			switch ( lCase( ARGUMENTS.operator ) ) {
				case "!=":
				case "<>":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$ne" : ARGUMENTS.value };
					break;
				case ">":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$gt" : ARGUMENTS.value };
					break;
				case "<":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$lt" : ARGUMENTS.value };
					break;
				case ">=":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$gte" : ARGUMENTS.value };
					break;
				case "<=":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$lte" : ARGUMENTS.value };
					break;
				case "in":
					VARIABLES._criteria[ ARGUMENTS.key ] = { "$in" : ARGUMENTS.value };
					break;
				default:
					VARIABLES._criteria[ ARGUMENTS.key ] = ARGUMENTS.value;
					break;
			}
			this.criteria( criteria );
			return this;
		}
	}

	/**
	 * Convenience function to exclude the current active entity
	 *
	 * If the entity is not loaded, no query restrictions will be added
	 */
	any function whereNotI(){
		if ( this.loaded() ) {
			this.where( "_id", "!=", this.get_id() );
		}
		return this;
	}

	/**
	 * Set maxrows|limit for query
	 *
	 * @chainable
	 */
	any function limit( numeric max ){
		this.set_limit( arguments.max );

		return this;
	}

	/**
	 * Set the offset for a query
	 *
	 * @chainable
	 */
	any function offset( numeric offset ){
		this.set_offset( arguments.offset );

		return this;
	}

	/**
	 * Set the order|sort for the upcoming query
	 *
	 * @chainable
	 */

	/**
	 * Set the order|sort for the upcoming query
	 *
	 * @chainable
	 * @key       the key to sort by
	 * @direction the direction in which to sort
	 */
	any function order( key, direction ){
		if ( !isNumeric( direction ) ) {
			switch ( lCase( direction ) ) {
				case "desc":
					arguments.direction = -1;
					break;
				case "asc":
					arguments.direction = 1;
					break;
				default:
					throw(
						type    = "CBMongodb.InvalidSortException",
						message = "The value #arguments.direction# could not be parsed in to a valid MongoDB sort direction"
					);
			}
		}

		variables._sort[ key ] = arguments.direction;

		return this;
	}

	/**
	 * Find one record and return the query
	 *
	 * @chainable
	 */
	any function find( returnInstance = true, asJSON = false ){
		var results = this.limit( 1 ).findAll();
		if ( arrayLen( results ) ) {
			this.entity( results[ 1 ] );
			if ( asJSON ) {
				return serializeJSON( results[ 1 ] );
			}
			if ( !returnInstance ) {
				return results[ 1 ];
			}
		} else if ( !returnInstance ) {
			return;
		}
		if ( asJSON ) {
			return;
		} else {
			return this;
		}
	}


	/**
	 * Find all records matching the current query params
	 *
	 * @param boolean asCursor - whether to return the array as a Mongo cursor object (e.g. cursor.next())
	 */
	any function findAll(
		asCursor = false,
		asResult = false,
		asJSON   = false
	){
		if ( isNull( this.getXCollection() ) ) {
			var results = this.query();
		} else {
			var results = this.mapReduce();
		}

		if ( arguments.asResult ) return results;

		if ( asCursor ) return results.asCursor();

		if ( asJSON ) return results.asJSON();

		return results.asArray();
	}


	/**
	 * Test whether a record matching the current criteria exists
	 */
	boolean function exists(){
		return ( this.count() GT 0 );
	}

	/**
	 * Count the records in the current query
	 */
	numeric function count(){
		return this.getDbInstance().count( this.get_criteria() );
	}

	/**
	 * Delete a document, with optional truncate flag
	 *
	 * @param boolean truncate - with this set to false, a delete will not proceed without either a loaded entity or an existing criteria
	 */
	boolean function delete( truncate = false ){
		var deleted = false;

		if ( !truncate && !this.loaded() && !this.criteriaExists() ) {
			// protect from an accidental truncation
			throw(
				type    = "InvalidData",
				message = "No loaded record or criteria specified. If you wish to truncate this collection, pass the truncate=true flag to this method"
			);
		} else if ( !this.loaded() && this.criteriaExists() ) {
			// delete by criteria
			deleted = javacast( "boolean", getDBInstance().remove( this.get_criteria() ).getDeletedCount() );
			this.reset();
		} else if ( !this.loaded() && !this.criteriaExists() && truncate ) {
			// authorized truncation
			deleted = javacast(
				"boolean",
				this.getDBInstance()
					.remove( criteria = {} )
					.getDeletedCount()
			);
		} else if ( this.loaded() ) {
			// defaults to delete by the loaded id
			deleted = super.delete( this.get_id() );
			this.reset();
		}

		return deleted;
	}

	/****************************** Validation Methods *******************************/

	/**
	 * The core validation function for the loaded or populated entity
	 */
	boolean function isValid(){
		// reset our validation
		set_validation( newValidation() );

		var modelMap = this.get_map();

		var doc = this.get_document();

		for ( var mapkey in modelMap ) {
			var mapping = modelMap[ mapkey ];

			// must be in schema
			if ( isNull( this.locate( mapkey ) ) ) {
				createValidationError( mapping, "missing" );
				continue;
			}

			var fieldValue = this.locate( mapkey );

			// field is required

			if (
				structKeyExists( mapping, "required" ) && mapping.required && isSimpleValue( fieldValue ) && !len(
					fieldValue
				)
			) {
				createValidationError( mapping, "required", fieldValue );
				continue;
			}

			if (
				structKeyExists( mapping, "length" ) && isSimpleValue( fieldValue ) && len( fieldValue ) && len(
					fieldValue
				) != mapping.length
			) {
				createValidationError( mapping, "length", fieldValue );
				continue;
			}

			if (
				structKeyExists( mapping, "validate" )
				&&
				(
					structKeyExists( mapping, "required" )
					||
					(
						!isSimpleValue( fieldValue )
						||
						(
							isSimpleValue( fieldValue )
							&&
							len( fieldValue )
						)
					)
				)
				&&
				!fieldIsValid( fieldValue, mapping )
			) {
				createValidationError( mapping, "validation", fieldValue );
				continue;
			}

			// field is unique
			if ( structKeyExists( mapping, "unique" ) && mapping.unique ) {
				var uniqueCriteria = { "#mapkey#" : fieldValue };

				if ( this.loaded() )
					uniqueCriteria[ "_id" ] = { "$ne" : getMongoUtil().newObjectIdFromId( this.get_id() ) };

				if ( javacast( "boolean", getDbInstance().count( uniqueCriteria ) ) ) {
					createValidationError( mapping, "unique", fieldValue );
					continue;
				}
			}
		}

		return get_validation().success;
	}

	/**
	 * Checks whether a field meets its validation requirement
	 *
	 * @param any fieldValue		The value of the field
	 * @param struct mapping		The mapping key for this field
	 */
	boolean function fieldIsValid( required fieldValue, required mapping ){
		// return true if no validation parameters are specified
		if ( !structKeyExists( arguments.mapping, "validate" ) ) return true;

		// use the native isValid method, which will provide the descriptive error if our validation attribute is not a CFML type
		return isValid( arguments.mapping.validate, arguments.fieldValue );
	}

	/**
	 * Creates a standardized format validation error
	 *
	 * @param struct mapping		The mapping key (property name) for this field
	 * @param string errorType		The error type to append to the validation errors array
	 * @param any [fieldValue]		The value of the field, if any
	 */
	void function createValidationError(
		required mapping,
		required string errorType = "validation",
		any fieldValue
	){
		var validations     = get_validation();
		validations.success = false;

		var error = {
			"type"      : arguments.errorType,
			"fieldName" : mapping.name,
			"mapping"   : mapping
		};

		switch ( arguments.errorType ) {
			case "missing":
				error[ "message" ]     = "Missing document field #mapping.name#";
				error[ "description" ] = "The #mapping.name# field is missing from the document.";
				break;
			case "validation":
				error[ "message" ]     = "Invalid field value type for property #mapping.name#";
				error[ "description" ] = "Property #mapping.name# failed validation for type #mapping.validate#.  The type received was #getMetadata( fieldValue ).name#";
				break;
			case "unique":
				error[ "message" ]     = "The value of #mapping.name# is not unique";
				error[ "description" ] = "The value #fieldValue# for property #mapping.name# failed validation because the field value must be unique.";
				break;
			case "length":
				error[ "message" ]     = "The value of #mapping.name# fails to meet the specified length of #mapping.length#";
				error[ "description" ] = "The value #fieldValue# for property #mapping.name# failed validation because the length of the field must be equal to #mapping.length#.";
				break;
			case "required":
				error[ "message" ]     = "Field #mapping.name# is required";
				error[ "description" ] = "#mapping.name# is a required field";
				break;
			default:
				error[ "message" ]     = "An unknown validation error occurred for property #mapping.name#";
				error[ "description" ] = "";
		}

		if ( !isNull( fieldValue ) ) {
			error[ "fieldValue" ] = fieldValue;
		}

		arrayAppend( validations.errors, error );

		this.set_validation( validations );
	}

	/**
	 * Returns the results of the validation
	 *
	 * @return null if validation has not been run on the entity | struct if validation has processed
	 */
	any function getValidationResults(){
		return get_validation();
	}

	/**
	 * Returns the array of validation errors or null if validation has not been run on the entity
	 */
	any function getValidationErrors(){
		if ( !isNull( get_validation() ) && structKeyExists( get_validation(), "errors" ) ) {
			return get_validation().errors;
		}
	}

	/**
	 * Returns the standardized validations structure
	 */
	struct function newValidation(){
		return { "success" : true, "errors" : [] };
	}

	/****************************** Status Control Methods *******************************/

	/**
	 * Tests whether this is a loaded entity()
	 */
	boolean function loaded(){
		return ( !isNull( this.get_id() ) && structKeyExists( this.get_document(), "_id" ) );
	}

	/**
	 * Reloads the loaded entity from the database
	 */
	any function reload(){
		var entityId = this.get_id();
		this.reset();
		return this.load( entityId );
	}


	/**************************** Cross Collection Queries ************************/

	any function join( required collection ){
		this.setXCollection( arguments.collection );

		return this;
	}

	any function on( required key, operator = "=", required xKey ){
		if ( isNull( this.getXCollection() ) )
			throw( "The collection to be joined does not exist.  Please use the <strong>join(required collection)</strong> function to specify this collection before calling <strong>on()</strong>." );

		// TODO: this methodology needs to be adjusted so we can use this for many-to-many through relationship
		var mapkey = getMetadata( this ).name & arguments.key & this.getXCollection() & operator & arguments.xKey;

		if ( this.loaded() ) {
			mapkey = this.get_id() & mapkey;
		}

		var mr = { "map" : hash( mapkey ) };
	}


	/**************************** Package Methods *********************************/

	/**
	 * Scopes the active entity
	 */
	any function entity( struct record ){
		// ensure our default document is merged in to handle any changes
		structAppend(
			arguments.record,
			get_default_document(),
			false
		);

		// ensure the entity _id is always cast as a string
		if ( structKeyExists( record, "_id" ) && getMongoUtil().isObjectId( record[ "_id" ] ) ) {
			record[ "_id" ] = record[ "_id" ].toString();
		}

		this.set_document( record );
		this.set_existing( record );

		this.scopeEntity( this.get_document() );
	}

	/**
	 * Handles the individual key scoping for entity()
	 */
	any function scopeEntity( doc ){
		for ( var record in doc ) {
			// ensure nulls are not handled
			if ( !isNull( doc[ record ] ) ) {
				variables[ record ] = doc[ record ];
			}
		}
	}

	any function clearScope(){
		// TODO: Clean up the encapsulation issues between the super scope and this
		this.resetQuery();
		this.set_id( "" );
		for ( var prop in get_map() ) {
			this.set( prop, this.getPropertyDefault( variables._map[ prop ] ) );
		}
	}

	/**
	 * overload the upstream evict to clear query params
	 */
	any function evict(){
		super.evict();
		this.clearScope();
	}


	any function resetQuery( evict = true ){
		this.criteria( structNew() );
		this.set_keys( "" );
		this.set_offset( 0 );
		this.set_limit( 0 );
		this.set_sort( structNew() );

		// clear our cross-collection params
		structDelete( variables, "xCollection" );
		structDelete( variables, "xReduce" );
	}

	boolean function criteriaExists(){
		if ( structIsEmpty( this.get_criteria() ) ) return false;

		return true;
	}

	any function appendCriteria( struct criteria ){
		structAppend( this.get_criteria(), ARGUMENTS.criteria, true );

		return this;
	}

}
