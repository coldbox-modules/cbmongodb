/*******************************************************************************
 *	Unit Tests for cbmongodb.models.Mongo.MongoUtil
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" {

	function run( testResults, testBox ){
		describe( "Tests Core Object Types", function(){
			it( "tests toMongoDocument()", function(){
				// we can only test for the word `java` because of ACFs custom wrapper class
				expect( getMetadata( MongoUtil.toMongoDocument( {} ) ).getCanonicalName() ).toContain( "java" );
			} );

			it( "tests toCF()", function(){
				expect( MongoUtil.toCF( MongoUtil.toMongoDocument( {} ) ) ).toBeStruct();
			} );

			it( "tests newObjectIDFromID()", function(){
				var testId = "53e787bd3773887239e56b17";
				expect( getMetadata( MongoUtil.newObjectIDFromID( testId ) ).getCanonicalName() ).toBe( "org.bson.types.ObjectId" );
			} );

			// Skipping until we can figure out why ACF can't handle the Java object anymore in 2023+
			xit( "tests newIDCriteriaObject", function(){
				var testId = "53e787bd3773887239e56b17";
				// we can only test for the word `java` because of ACFs custom wrapper class
				expect( getMetadata( MongoUtil.newIDCriteriaObject( testId ) ).getCanonicalName() ).toContain( "java" );
				var idCriteria = MongoUtil.newIDCriteriaObject( testId );
				expect( getMetadata( idCriteria[ "_id" ] ).getCanonicalName() ).toBe( "org.bson.types.ObjectId" );
			} );

			xit( "tests dbObjectNew()", function(){
				var s = { "_id" : "53e787bd3773887239e56b17" };
				// we can only test for the word `java` because of ACFs custom wrapper class
				expect( getMetadata( MongoUtil.dbObjectNew( s ) ).getCanonicalName() ).toContain( "java" );
				var dbObject = MongoUtil.dbObjectNew( s );
				expect( dbObject ).toHaveKey( "_id" );
			} );
		} );

		describe( "Tests DB Results", function(){
			it( "creates records for our tests", function(){
				MongoClient.getDBCollection( "MongoUtilTestCollection" ).drop();

				// we need to use the actual collection object to bypass our Collection facade
				variables.activeCollection = MongoClient
					.getDBCollection( "MongoUtilTestCollection" )
					.getDBCollection();
				for ( var i = 1; i <= 5; i = i + 1 ) {
					var doc = MongoUtil.toMongoDocument( { "one" : 1, "two" : 2, "three" : 3 } );
					variables.activeCollection.insertOne( doc );
				}
				expect( variables.activeCollection.countDocuments() ).toBe( 5 );
				describe( "Tests dbResult manipulation methods", function(){
					it( "tests the encapsulateDBResult() method", function(){
						var dbResult      = variables.activeCollection.find();
						var encapsulation = MongoUtil.encapsulateDBResult( dbResult );
						expect( encapsulation.asArray() ).toBeArray();
						// test our auto-stringification of the _id value
						expect( encapsulation.asArray()[ 1 ][ "_id" ] ).toBeString();
						expect( arrayLen( encapsulation.asArray() ) ).toBe( 5 );
						expect( getMetadata( encapsulation.asCursor() ).getCanonicalName() ).toBe( "com.mongodb.client.internal.MongoBatchCursorAdapter" );
						expect( encapsulation.asCursor().hasNext() ).toBeTrue();
						var next = encapsulation.asCursor().next();
						expect( next ).toHaveKey( "one" );
						expect( next ).toHaveKey( "two" );
						expect( next ).toHaveKey( "three" );

						expect( isJSON( encapsulation.asJSON() ) ).toBeTrue();
						expect( deserializeJSON( encapsulation.asJSON() ) ).toBeArray();
					} );
				} );
			} );
		} );
	}

}
