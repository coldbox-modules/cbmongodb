/*******************************************************************************
 *	Integration Test for /cfmongodb/models/ActiveEntity.cfc
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" {

	function beforeAll(){
		// custom methods
		super.beforeAll();
		expect( variables.people ).toBeComponent();
		expect( variables.people.get_default_document() ).toBeStruct();
		expect( variables.people.getTestDocument() ).toBeStruct();

		// var scope our references for the remaining tests
		VARIABLES.model   = variables.people;
		VARIABLES.person  = variables.people.getTestDocument();
		VARIABLES.person2 = variables.people.getTestDocument2();
	}

	function afterAll(){
		super.afterAll();
		// var a = b;
	}

	function run( testResults, testBox ){
		describe( "Tests modifications to entity scopes", function(){
			it( "Tests custom accessor availability and accuracy", function(){
				var testData = variables.people.getTestDocument();
				model.reset().populate( testData );
				for ( var prop in getMetadata( model ).properties ) {
					if ( structKeyExists( prop, "schema" ) && prop.schema ) {
						var setter = model[ "set" & replace( prop.name, ".", "_", "ALL" ) ];
						var getter = model[ "get" & replace( prop.name, ".", "_", "ALL" ) ];
						expect( setter( model.locate( prop.name ) ) ).toBeComponent();
						expect( getter() ).toBe( model.locate( prop.name ) );
					}
				}
			} );
		} );

		describe( "Verifies CRUD Functionality", function(){
			it( "Tests basic validation", function(){
				expect( model.populate( person ) ).toBeComponent();
				expect( model.isValid() ).toBeTrue();
				expect( model.getValidationResults() ).toHaveKey( "success" );
				expect( model.getValidationResults() ).toHaveKey( "errors" );
				expect( model.getValidationResults().success ).toBeTrue();
				expect( arrayLen( model.getValidationResults().errors ) ).toBe( 0 );

				// set some invalid results

				// state length
				// check that it validates if empty
				model.set( "address.state", "" );
				expect( model.isValid() ).toBeTrue();
				model.set( "address.state", "Michigan" );
				expect( model.isValid() ).toBeFalse( "State field with a length greater than 2 validated true incorrectly" );
				expect( arrayLen( model.getValidationResults().errors ) ).toBe(
					1,
					"State field length validation failed"
				);
				model.set( "address.state", "MI" );


				// telephone validation
				model.set( "phone.home", "ABCDEF~GH%IJkL$MNO%PQRS" );
				expect( model.isValid() ).toBeFalse( "Telephone field validated true incorrectly" );
				expect( arrayLen( model.getValidationResults().errors ) ).toBe( 1, "Telephone validation failed" );

				// set a required field as blank
				model.set( "phone.home", "" );
				expect( model.isValid() ).toBeFalse( "Telephone field was required and validated true incorrectly" );
				expect( arrayLen( model.getValidationResults().errors ) ).toBe( 1, "Telephone validation failed" );


				// postal code
				model.set( "address.postalcode", "ABCDEF~GH%IJkL$MNO%PQRS" );
				expect( model.isValid() ).toBeFalse( "PostalCode field validated true incorrectly" );
				expect( arrayLen( model.getValidationResults().errors ) ).toBe(
					2,
					"Postal code validation failed"
				);

				// test removing a required key
				structDelete( model.get_document(), "address" );
				expect( model.isValid() ).toBeFalse( "Nullified field validated incorrectly" );
				// should have errors for all of our missing document keys
				expect( arrayLen( model.getValidationResults().errors ) ).toBe( 8 );
			} );

			it( "Tests entity insert operations", function(){
				// ensure we have an empty collection
				model.reset().delete( truncate = true );
				expect( model.count() ).toBe( 0 );
				expect( model.reset().populate( variables.people.getTestDocument() ) ).toBeComponent();
				var document_id = model.create();
				expect( document_id ).toBeString();
				VARIABLES.testDocumentID = document_id;

				writeDump( testDocumentId );
				writeDump( model.reset().load( document_id, false ) );
				abort;
				// test entity load
				expect(
					model
						.reset()
						.load( document_id )
						.loaded()
				).toBeTrue();

				expect( model.whereNotI().count() ).toBe( 0 );

				var criteria = { "phone.home" : "616-515-2121" };

				var projection = MongoUtil.toMongo( { "first_name" : 1, "last_name" : 1 } );

				var projected = model
					.reset()
					.getCollectionObject()
					.find( criteria = criteria )
					.getResult()
					.projection( projection )
					.iterator()
					.tryNext();

				expect( isNull( projected ) ).toBeFalse();
				expect( projected ).toHaveKey( "first_name" );
				expect( projected ).toHaveKey( "last_name" );
				expect( structKeyExists( projected, "phone" ) ).toBeFalse();
			} );
		} );

		describe( "Test auto-normalization", function(){
			it( "Tests auto-normalization methods on a nested field of the target", function(){
				// create our counties
				// load one county
				for ( var county in Counties.getTestDocuments() ) {
					var county_id = Counties
						.reset()
						.populate( county )
						.create();
					expect( county_id ).toBeString( "County Id is not a string" );
					break;
				}
				expect( VARIABLES ).toHaveKey(
					"testDocumentID",
					"A Document ID does not exist to test normalization"
				);

				var document_id = VARIABLES.testDocumentID;

				var Normie = model.reset().load( document_id );
				expect( Normie.loaded() ).toBeTrue( "The test document could not be reloaded to test normalization" );
				model.set( "county.id", county_id );

				var normalizedCounty = model.getCounty();
				expect( normalizedCounty ).toBeStruct();
				expect( normalizedCounty ).toHaveKey( "id" );
				expect( normalizedCounty ).toHaveKey( "name" );
				expect( normalizedCounty.name ).toBe( county.name );
				expect( normalizedCounty ).toHaveKey( "geometry" );
				expect( isSimpleValue( normalizedCounty.geometry ) ).toBeFalse();

				// test auto-normalization with a separate target and top-level key
				model.set( "countyId", county_id );

				var normalizedCountyTwo = model.getCountyTwo();
				expect( normalizedCountyTwo ).toBeStruct();
				expect( normalizedCountyTwo ).toHaveKey( "name" );
				expect( normalizedCountyTwo.name ).toBe( county.name );
				expect( normalizedCountyTwo ).toHaveKey( "geometry" );
			} );
		} );

		describe( "Tests General Entity Operations", function(){
			it( "Tests entity retrieval operations", function(){
				// test our single record queries
				expect(
					model
						.reset()
						.where( "address.city", "Timbuktu" )
						.find( false )
				).toBeNull();
				expect(
					model
						.reset()
						.where( "address.city", "Timbuktu" )
						.find()
				).toBeComponent();
				expect(
					model
						.reset()
						.where( "address.city", "Timbuktu" )
						.find()
						.loaded()
				).toBeFalse();
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.find( false )
				).toBeStruct();
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.find( asJSON = true )
				).toBeTypeOf( "string" );
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.findAll()
				).toBeArray();
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.findAll( asJSON = true )
				).toBeTypeOf( "string" );
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.find()
				).toBeComponent();
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.count()
				).toBe( 1 );
				expect(
					model
						.reset()
						.where( "address.city", model.getTestDocument().address.city )
						.exists()
				).toBeTrue();
			} );

			it( "Tests the ability for where() to accept a struct as the first argument", function(){
				expect(
					model
						.reset()
						.where( { "address.city" : "Timbuktu" } )
						.find( false )
				).toBeNull();
				expect(
					model
						.reset()
						.where( { "address.city" : "Timbuktu" } )
						.find()
				).toBeComponent();
				expect(
					model
						.reset()
						.where( { "address.city" : "Timbuktu" } )
						.find()
						.loaded()
				).toBeFalse();
				expect(
					model
						.reset()
						.where( { "address.city" : model.getTestDocument().address.city } )
						.find( false )
				).toBeStruct();
				expect(
					model
						.reset()
						.where( { "address.city" : model.getTestDocument().address.city } )
						.find()
				).toBeComponent();
				expect(
					model
						.reset()
						.where( { "address.city" : model.getTestDocument().address.city } )
						.count()
				).toBe( 1 );
				expect(
					model
						.reset()
						.where( { "address.city" : model.getTestDocument().address.city } )
						.exists()
				).toBeTrue();
			} );

			it( "Tests that passing a struct twice as a where() argument appends the criteria", function(){
				model
					.reset()
					.where( { "address.city" : model.getTestDocument().address.city } )
					.where( { "first_name" : model.getTestDocument().first_name } );

				expect( model.get_criteria() ).toHaveKey( "address.city" );
				expect( model.get_criteria() ).toHaveKey( "first_name" );
			} );

			it( "Tests entity update operations", function(){
				// test our updates
				var ae = model
					.reset()
					.where( "address.city", model.getTestDocument().address.city )
					.find();
				expect( ae.loaded() ).toBeTrue();
				var document_id = ae.get_id();
				ae.set( "address.city", "Chicago" )
					.set( "address.state", "IL" )
					.set( "address.postalcode", "60622" )
					.update();
				expect( ae.get_document()[ "address" ][ "city" ] ).toBe( "Chicago" );
				expect(
					model
						.reset()
						.where( "address.city", "Chicago" )
						.find()
						.loaded()
				).toBeTrue();
				// check that we updated the first record
				expect(
					model
						.reset()
						.where( "address.city", "Chicago" )
						.count()
				).toBe( 1 );
				// test our multi record queries

				// insert a duplicate record
				model.reset().populate( model.getTestDocument() );
				model
					.set( "first_name", "Second" )
					.set( "last_name", "Record" )
					.create();
				expect( model.loaded() ).toBeTrue();
				// test multiple records
				var all_docs = model.reset().findAll();
				expect( all_docs ).toBeArray();
				expect( arrayLen( all_docs ) ).toBe( 2 );
				// test our limit()
				expect(
					arrayLen(
						model
							.reset()
							.limit( 1 )
							.findAll()
					)
				).toBe( 1 );
				expect(
					arrayLen(
						model
							.reset()
							.get( document_id )
							.whereNotI()
							.findAll()
					)
				).toBe( 1 );
			} );


			it( "Tests the order() method", function(){
				expect( model.reset().populate( variables.people.getTestDocument2() ) ).toBeComponent();
				var document_id = model.create();
				expect( document_id ).toBeString();

				model.reset();
				model.order( "address.city", "asc" );

				var results = model.findAll();

				expect( results ).toBeArray();

				expect( arrayLen( results ) ).toBe( 3 );

				expect( results[ 1 ].address.city ).toBe( "Chicago" );
				expect( results[ 2 ].address.city ).toBe( "Chicago" );
				expect( results[ 3 ].address.city ).toBe( "Grand Rapids" );

				model.reset();
				model.order( "address.city", "desc" );

				var results = model.findAll();

				expect( results ).toBeArray();

				expect( arrayLen( results ) ).toBe( 3 );

				expect( results[ 1 ].address.city ).toBe( "Grand Rapids" );
				expect( results[ 2 ].address.city ).toBe( "Chicago" );
				expect( results[ 3 ].address.city ).toBe( "Chicago" );
			} );

			it( "Tests cursor operations and entity deletion", function(){
				// cursor tests
				var cursor = model.reset().findAll( true );
				expect( isArray( cursor ) ).toBeFalse();
				expect( cursor.hasNext() ).toBeTrue();
				while ( cursor.hasNext() ) {
					var nr     = cursor.next();
					var doc_id = nr[ "_id" ];
					expect( nr ).toBeStruct();
					expect( nr ).toHaveKey( "first_name" );
					expect( nr ).toHaveKey( "address" );
					// now delete our records
					expect(
						model
							.reset()
							.get( doc_id )
							.delete()
					).toBeTrue();
					expect(
						model
							.reset()
							.get( doc_id )
							.loaded()
					).toBeFalse();
				}
			} );
		} );
	}

}
