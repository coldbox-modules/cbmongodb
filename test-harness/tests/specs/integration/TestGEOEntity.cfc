/*******************************************************************************
 *	Integration Test for /cfmongodb/models/GEOEntity.cfc
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" accessors=true {

	function beforeAll(){
		// custom methods
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}


	function run( testResults, testBox ){
		describe( "MongoDB Active Entity", function(){
			it( "creates our test geospatial data", function(){
				var person = variables.people;
				expect( person.populate( person.getTestDocument() ) ).toBeComponent();
				var document_id = person.create();
				expect( document_id ).toBeString();
				var state = variables.states;

				expect( state.populate( state.getTestDocument() ) ).toBeComponent();
				var state_id = state.create();

				expect( state_id ).toBeString();


				// load our counties
				for ( var county in Counties.getTestDocuments() ) {
					var county_id = Counties
						.reset()
						.populate( county )
						.create();
					expect( county_id ).toBeString();
				}

				expect( arrayLen( Counties.reset().findAll() ) ).toBe( 4 );

				describe( "performs our geospatial comparison tests", function(){
					it( "tests within() comparisons", function(){
						expect(
							arrayLen(
								state
									.load( state_id )
									.within( "geometry", "People@CBMongoTestMocks.address.location" )
									.findAll()
							)
						).toBe( 1 );

						var reload = state.reset().get( state_id );

						expect( reload.loaded() ).toBeTrue( "State could not be reloaded" );

						expect( reload.within( "geometry", "Counties@CBMongoTestMocks.geometry" ).count() ).toBe(
							4
						);
					} );

					it( "tests near() comparisons", function(){
						var kent = counties
							.reset()
							.where( "name", "Kent" )
							.find();

						expect( kent ).toBeComponent();

						expect(
							arrayLen(
								kent.whereNotI()
									.near( "geometry", "this.geometry" )
									.findAll()
							)
						).toBe( 3 );
					} );
				} );
			} );
		} );
	}

}
