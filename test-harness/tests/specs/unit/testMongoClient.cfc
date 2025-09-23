/*******************************************************************************
 *	Unit Tests for cbmongodb.models.Mongo.MongoClient
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" {

	function run( testResults, testBox ){
		describe( "Test Client Immutability", function(){
			it( "tests Collection Immutability", function(){
				var person = Wirebox.getInstance( "People@CBMongoTestMocks" );
				expect( person.getCollectionObject().getCollectionName() ).toBe( "people" );
				var state = Wirebox.getInstance( "States@CBMongoTestMocks" );

				expect( state.getCollectionObject().getCollectionName() ).toBe( "states" );
				// person.findAll();
				expect( person.getCollectionObject().getCollectionName() ).toBe( "people" );

				var county = Wirebox.getInstance( "Counties@CBMongoTestMocks" );
				expect( county.getCollectionObject().getCollectionName() ).toBe( "counties" );
				// state.findAll();
				expect( state.getCollectionObject().getCollectionName() ).toBe( "states" );
				// person.findAll();
				expect( person.getCollectionObject().getCollectionName() ).toBe( "people" );
			} );
		} );
	}

}
