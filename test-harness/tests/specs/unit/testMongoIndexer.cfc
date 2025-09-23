/*******************************************************************************
 *	Unit Tests for cbmongodb.models.Mongo.Indexer
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" {

	function run( testResults, testBox ){
		describe( "Tests Core Indexing Methods", function(){
			it( "tests the singleton persistence of the indexer", function(){
				var PersonModel = People;
				var StatesModel = States;

				// Instantiation will have already have created our index maps for the singleton
				expect( PersonModel.getMongoIndexer().getMap() ).toBeArray();
				expect( arrayIsEmpty( PersonModel.getMongoIndexer().getMap() ) ).toBeFalse();
				expect( PersonModel.getMongoIndexer().getIndexNames() ).toBeArray();
				expect( arrayIsEmpty( PersonModel.getMongoIndexer().getIndexNames() ) ).toBeFalse();

				var personIndexNames = PersonModel.getMongoIndexer().getIndexNames();

				expect( StatesModel.getMongoIndexer().getMap() ).toBeArray();
				expect( arrayIsEmpty( StatesModel.getMongoIndexer().getMap() ) ).toBeFalse();
				expect( StatesModel.getMongoIndexer().getIndexNames() ).toBeArray();
				expect( arrayIsEmpty( StatesModel.getMongoIndexer().getIndexNames() ) ).toBeFalse();
				for ( var personIndexName in personIndexNames ) {
					expect( arrayContains( StatesModel.getMongoIndexer().getIndexNames(), personIndexName ) ).toBeTrue( "Person index names are not contained in the StatesModel indexer names object. Key missing: #personIndexName#" );
				}
			} );

			it( "Tests the return types of the indexer", function(){
				var PersonModel    = People;
				var testDbInstance = PersonModel.getDbInstance();
				var indexer        = PersonModel.getMongoIndexer();
				expect( indexer.getIndexInfo( testDBInstance ) ).toBeArray( "getIndexInfo() did not return an array." );
				expect( indexer.indexExists( testDbInstance, "fakeindex" ) ).toBeFalse();
				expect( indexer.indexOrder( { "indexorder" : "desc" } ) ).toBe( -1 );
			} );
		} );
	}

}
