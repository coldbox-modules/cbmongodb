# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

* * *

## [Unreleased]

## [4.0.0] - 2025-10-02

### Changed

- Updates MongoDb Driver to v4.9.1
- MongoDB v7/8 compatibility
- Drop support for Adobe &lt; 2023
- Drop support for Lucee &lt; 5

## [v3.11.1.0]

### Changed

- Updates MongoDB driver to v3.11.0

## [v3.5.1.0]

### Changed

- Updates MongoDB driver to v3.5.0
- Fixes an issue with incorrect sort results when using the ActiveEntity order() function

## [v3.2.1.1]

### Changed

- ACF Compatibility Updates
- Cleanup validation conditionals
- Adds the ability to pass an additional match condition on a grouped aggregation - Allows for an additional match clause to limit the grouped results
- Fixes casting errors on loaded entity save
- Ensure entity \_id is always cast as a string
- Fixes merge issue with struct merge on population
- Add check for \_id in record struct

## [v3.2.1.1]

### Changed

- Syntax corrections
- Reverts auto-eviction to pre-v3.2.0.4 spec to prevent removal of normalized data prior to `populate()`
- Ensures legacy index names, which weren't keyed off of the collection are dropped and re-created using new naming conventions

## [v3.2.1.0]

### Changed

- Updates Mongo Driver to v3.2.1.0
- ACF11 compatibility updates
- Refactors module to use coldbox module skeleton
- Adds automated Travis CI builds and deployments for source and new `cbmongodb-be` slug to Forgebox

## [v3.2.0.4]

### Changed

- Fixes a schema issue where a parent struct is being overwritten by the default container when the child attribute is lower aphabetically
- Fixes an issue with unique validation
- Fixes population issues when passing nested structs
- Fixes issues with nested keys on normalization
- Adds auto-eviction prior to population
- Adds explicit closing to cursor use for single record retrieval
- Changes index naming scheme to prevent different collections from having the same index name hash
- Adds the ability to pass a struct as the first argument to `where()`

## [v3.2.0.3]

### Changed

- Fixes ACF Compatibility Issues

## [v3.2.0.2]

### Changed

- Fixes issues with unexpected driver return types
- Adds `offset()` helper method (alias for `set_offset()`) to ActiveEntity
- Adds `isObjectId()` helper method to MongoUtil for detecting whether an object is a Mongo \_id string

## [v3.2.0.1]

### Changed

- Fixes issues with module load/unload connection operations
- Adds GridFS operational support
- Adds GridFS FileEntity model
- Fixes issues with `_id` queries not being typed appropriately
- Fixes error when attempting to truncate a collection

## [v3.2.0.0]

### Changed

- Updates MongoDB Java driver to version 3.2.0
- Adds support for readConcern configuration option

## [v3.1.0.4:]

### Changed

- Adds validation methods for entities and support for new property `ForceValidation`, which will prevent saving of documents which do not validate
- Adds auto-normalization capabilities for schema properties.  When attributes are configured, schema will auto-normalize when set() and populate() methods are called.
- Implements full support for component accessors on all schema properties.  Var safe accessor closures are generated to allow recursion through an underscore delimiter (e.g. `getFirstLevel_SecondLevel()` to retrieve `getDocument().FirstLevel.SecondLevel`)
- Fixes native CFML data types not being sanitized on deeply nested structs and arrays.
- Add getDocument() and asStruct() utility methods, which can be used on unloaded and unloaded entities.
- Adds append() and prepend() functions to assit in managing document schema arrays.
- Fixes issues with property maps not being defined correctly and correct casting of boolean property defaults.
- Adds MongoIndexer singleton to delegate index management away from Entity instances.

## [v3.1.0.3:]

### Changed

- Fixes issue with connections not being pooled accurately and adds connection closing to module unload
- Moves module bindings to onLoad() to ensure availability of cbjavaloader module
- Changes return type of all single record retrievals inserts and updates to native structs and adds auto-stringification of \_id (eliminates the need for toString())
- Ensures version of returned object from findOneAndUpdate/findOneAndReplace operations is the after-save version

## [v3.1.0:]

### Changed

- Removes Requirement For CFMongoDB Module
- Adds Requirement for CBJavaloader Module
- Implements MongoDB 3.0 Driver
- Implements the ability to use multiple databases
- Implements the ability to configure databases at the entity level
- Implements Native Collection Methods for the 3.0 MongoCollection
- Implements CFML [Aggregation](https://docs.mongodb.org/manual/aggregation/) methods while allowing direct access to native driver methods
- Implements CFML [Map-Reduce](https://docs.mongodb.org/manual/core/map-reduce/) methods
- Demonstrates 52% reduction in query execution times and database operations from the previous version
- Implements handlers for API documentation (/cmbongodb/docs) and Unit Tests (/cbmongodb/tests)
- Fixes issue with near() GEOSpatial operations on Polygon objects
- Re-factors Test Suite to Require the Framework Context
- Adds an asJSON argument to find() and findAll() entity queries
- Encapsulates all Collection Result queries to provide the following delivery methods:  .asResult() - MongoIterable,  .asCursor() - MongoIterator, .asArray(), asJSON()

[unreleased]: https://github.com/coldbox-modules/cbmongodb/compare/v4.0.0...HEAD
[4.0.0]: https://github.com/coldbox-modules/cbmongodb/compare/f7f2457e98e4720b6bc35f798040dc3013a878bd...v4.0.0
