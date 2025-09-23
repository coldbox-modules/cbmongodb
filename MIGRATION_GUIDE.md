# MongoDB Java Driver 5.x Migration Guide

## Overview
This document outlines the changes made to upgrade CBMongoDB from MongoDB Java Driver 4.9.1 to 5.5.1.

## Key Changes Made

### 1. Dependency Updates (box.json)
- Updated all MongoDB driver JARs from version 4.9.1 to 5.5.1
- Updated changelog to reflect the new driver version

### 2. Client.cfc - Core Connection Management
**Before (4.9.1):**
```java
variables.Mongo = jLoader.create("com.mongodb.MongoClient");
MongoDb.init(MongoClientURI);
```

**After (5.5.1):**
```java
variables.MongoClients = jLoader.create("com.mongodb.client.MongoClients");
mongoClient = variables.MongoClients.create(connectionString);
```

**Key Changes:**
- Replaced deprecated `MongoClient` class with `MongoClients` factory
- Removed complex initialization patterns in favor of direct connection string or settings
- Updated `getMongo()` and `getMongoDB()` to return correct modern types
- Fixed `dropDatabase()`, `addUser()`, `getLastError()`, and `close()` methods

### 3. Config.cfc - Client Settings Management
**Before (4.9.1):**
```java
var builder = jLoader.create("com.mongodb.MongoClientOptions$Builder");
builder.connectTimeout(arg);
```

**After (5.5.1):**
```java
var builder = jLoader.create("com.mongodb.MongoClientSettings$Builder");
var socketSettingsBuilder = jLoader.create("com.mongodb.connection.SocketSettings$Builder");
socketSettingsBuilder.connectTimeout(arg, TimeUnit.MILLISECONDS);
```

**Key Changes:**
- Replaced `MongoClientOptions` with `MongoClientSettings`
- Updated all configuration methods to use proper builder pattern
- Added support for authentication and cluster settings within the builder
- Maintained backward compatibility with `getMongoClientOptions()`

### 4. Util.cfc - Document Creation
**Before (Legacy Support):**
```java
function newDBObject(){
    return jLoader.create("com.mongodb.BasicDBObject");
}
```

**After (Modern + Legacy):**
```java
function newDocument(){
    return jLoader.create("org.bson.Document");
}

function newDBObject(){
    return jLoader.create("com.mongodb.BasicDBObject"); // @deprecated
}
```

**Key Changes:**
- Added modern `newDocument()` method for BSON Documents
- Added `newIDCriteriaDocument()` as modern alternative
- Kept legacy methods but marked as deprecated

### 5. GridFS.cfc - Database References
**Before:**
```java
mongoClient.getMongo().getDb(dbInstance)
```

**After:**
```java
mongoClient.getMongo().getDatabase(dbInstance)
```

## Backward Compatibility

All changes maintain backward compatibility:
- Legacy methods are marked `@deprecated` but still functional
- Existing code will continue to work without modification
- New modern methods are available for future development

## Migration Benefits

1. **Performance**: MongoDB Driver 5.x includes significant performance improvements
2. **Security**: Enhanced authentication and connection security
3. **Features**: Access to latest MongoDB server features
4. **Support**: Active support and security updates
5. **Future-Proof**: Prepares for MongoDB 7.x and 8.x compatibility

## Testing Recommendations

1. **Connection Testing**: Verify connections work with your MongoDB setup
2. **CRUD Operations**: Test create, read, update, delete operations
3. **Authentication**: Test with username/password and connection strings
4. **GridFS**: Test file storage and retrieval if used
5. **Performance**: Compare performance with previous version

## Breaking Changes (Minimal)

1. `getLastError()` now returns null (modern error handling via exceptions)
2. `addUser()` is deprecated (use MongoDB admin tools for user management)
3. Some internal error messages may have changed

## Next Steps

1. Test the updated module in development environment
2. Verify all existing functionality works as expected
3. Update any application code to use modern Document methods when possible
4. Consider migrating from BasicDBObject to Document for new development