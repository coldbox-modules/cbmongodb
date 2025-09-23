/*******************************************************************************
 *	Integration Test for /cfmongodb/models/FileEntity.cfc
 *******************************************************************************/
component extends="tests.specs.CBMongoDBBaseTest" {

	function beforeAll(){
		// custom methods
		super.beforeAll();
	}

	function afterAll(){
		super.afterAll();
	}

	function run( testResults, testBox ){
		xdescribe( "Test the the file/entity relationships", function(){
			it( "Tests the ability to create a File entity", function(){
				// create a test person
				var personId = VARIABLES.people
					.reset()
					.populate( variables.people.getTestDocument() )
					.create();

				expect( personId ).toBeString();

				var FileEntity = VARIABLES.FileEntity;
				FileEntity.setPerson_id( personId );
				// test our normalization
				expect( FileEntity.getPerson() ).toBeStruct();
				expect( FileEntity.getPerson() ).toHaveKey( "first_name" );
				expect( FileEntity.getPerson() ).toHaveKey( "last_name" );
				// test that validation has failed because we don't have a file set
				expect( FileEntity.isValid() ).toBeFalse();
				var testFiles = directoryList(
					expandPath( "/tests/assets" ),
					false,
					"path",
					"*.jpeg"
				);
				// make sure we have at least two files to test
				expect( arrayLen( testFiles ) ).toBeGT(
					1,
					"Test image files were not found to test GridFS methods. You may add your own images to /cbmongodb/tests/assets/ to test the GridFS functionality"
				);
				var testFile1 = testFiles[ 1 ];
				var testFile2 = testFiles[ 2 ];
				// now set some file associations
				FileEntity.loadFile( testFile1 );
				expect( FileEntity.getFileId() ).toBeString();
				expect( FileEntity.isValid() ).toBeTrue();

				var fileEntityId = FileEntity.create();

				expect( fileEntityId ).toBeString();
				expect( FileEntity.loaded() ).toBeTrue();

				describe( "Tests the ability to retreive and update File Entities", function(){
					it( "Tests file eviction", function(){
						var retrieved = FileEntity.reset().load( fileEntityId );
						expect( isNull( retrieved.getGFSFileObject() ) ).toBeTrue();

						// retrieving our extension will scope the variable
						var fileExtension = retrieved.getExtension();
						expect( isNull( retrieved.getGFSFileObject() ) ).toBeFalse();

						// reset() will call the evict() overload
						retrieved.reset();
						expect( retrieved.loaded() ).toBeFalse();
						expect( isNull( retrieved.getGFSFileObject() ) ).toBeTrue();
					} );
					it( "Tests the ability to update a File Entity", function(){
						var retrieved = FileEntity.reset().load( fileEntityId );
						expect( retrieved.loaded() ).toBeTrue();

						// store our file so that we can verify it has been deleted
						var file1Id = retrieved.getFileId();
						expect( file1Id ).toBeString();

						// now replace our file - using our alias function this time
						retrieved.setFile( testFile2 ).update();

						expect( retrieved.getFileId() == file1Id ).toBeFalse();

						expect( isNull( retrieved.getGridFSInstance().findById( file1Id ) ) ).toBeTrue();
					} );

					it( "Tests image-specific functions for a GridFS image", function(){
						var retrieved = FileEntity.reset().load( fileEntityId );

						// pull an image object test our native image methods
						var imgObj = retrieved.getImageObject();

						expect( getMetadata( imgObj ).name ).toBe( "javaxt.io.Image" );

						// test our other metadata types
						var BufferedImage = retrieved.getBufferedImage();
						expect( getMetadata( BufferedImage ).name ).toBe( "java.awt.image.BufferedImage" );

						var ImageGraphics = retrieved.getImageGraphics();
						expect( getMetadata( ImageGraphics ).name ).toBe( "sun.java2d.SunGraphics2D" );

						var CFImage = retrieved.getCFImage();
						expect( CFImage ).toBeStruct();

						// grab our original height and width
						var originalHeight = imgObj.getHeight();
						var originalWidth  = imgObj.getWidth();

						// scale without crop
						imgObj.setHeight( 100 );
						imgObj.setWidth( 100 );
						expect( imgObj.getHeight() ).toBeLTE( 100 );
						expect( imgObj.getWidth() ).toBeLTE( 100 );
						var imgHeight = imgObj.getHeight();
						imgObj.rotate( 90 );
						expect( imgObj.getWidth() ).toBe( imgHeight );

						// now create a 100x100 image cropped from center
						var imgObj = retrieved.getImageObject( 100, 100, "center", "center" );
						expect( imgObj.getHeight() ).toBe( 100 );
						expect( imgObj.getWidth() ).toBe( 100 );
					} );



					it( "Tests the ability to write a GridFS entity to a file", function(){
						var writeable     = FileEntity.reset().load( fileEntityId );
						var fileId        = writeable.getFileId();
						var fileExtension = writeable.getExtension();
						var fileObj       = writeable.getFileObject();
						var fileName      = "BDDTestImage#writeable.getFileId()#.#fileExtension#";
						var filePath      = expandPath( "/tests/assets/tmp" );
						if ( !directoryExists( filePath ) ) directoryCreate( filePath );

						var written = writeable.writeTo( filePath & "/" & fileName );

						expect( written ).toBe( filePath & "/" & fileName );
						expect( fileExists( filePath & "/" & fileName ) ).toBeTrue();

						fileDelete( filePath & "/" & fileName );

						// now test with just the directory as the path
						var written = writeable.writeTo( filePath );
						expect( listLast( written, "/" ) ).toBe( fileId & "." & fileExtension );
						expect( fileExists( written ) ).toBeTrue();

						fileDelete( written );
					} );


					it( "Test the ability to delete a File Entity", function(){
						var testDeletion = FileEntity.reset().load( fileEntityId );
						expect( testDeletion.loaded() ).toBeTrue();

						var fileId = testDeletion.getFileId();
						expect( len( fileId ) ).toBeGt( 0 );

						testDeletion.delete();

						expect(
							FileEntity
								.reset()
								.load( fileEntityId )
								.loaded()
						).toBeFalse();
						expect( isNull( FileEntity.getGridFSInstance().findById( fileId ) ) ).toBeTrue();
					} );
				} );
			} );
		} );
	}

}
