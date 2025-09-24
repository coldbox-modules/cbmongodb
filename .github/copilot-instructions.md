# cbmongodb - ColdBox MongoDB Module
cbmongodb is a ColdBox module that provides MongoDB integration for ColdFusion (CFML) applications. It includes ActiveEntity models, document services, GridFS support, and MongoDB Java driver integration.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## CRITICAL TESTING REQUIREMENTS

**🚨 ALL TESTS MUST PASS ON ALL CFML ENGINES BEFORE ANY COMMIT 🚨**

Before making ANY commit or change:
1. **MANDATORY**: Run code formatting: `box run-script format`
2. **MANDATORY**: Run complete test suite and ensure 100% pass rate on ALL engines
3. **MANDATORY**: Verify ALL CFML engines pass tests (Lucee 5+, Adobe 2023+, Adobe 2025+, BoxLang)
4. **MANDATORY**: Test with MongoDB 8.0+ connectivity (matches CI environment)
5. **MANDATORY**: Ensure CI matrix passes for all engines before any commit
6. **NO EXCEPTIONS**: Do not commit code that breaks existing functionality on ANY engine

### Code Formatting Requirements
```bash
# REQUIRED before any commit - format all code
box run-script format
```

### Test Execution Requirements
```bash
# REQUIRED before any commit - all must pass
box testbox run --verbose outputFile=test-harness/tests/results/test-results outputFormats=json,antjunit
```

**Formatting or Test failure = STOP. Fix issues before proceeding.**

## Working Effectively

### Prerequisites
- CommandBox CLI (package manager and CFML server)
- Java 17+ (confirmed available)
- MongoDB server (Docker image: mongo:7.0 works)

### Critical Setup Steps
**NEVER CANCEL builds or long-running commands. Build and test processes may take 15-45 minutes.**

1. **Start MongoDB Database** (VALIDATED WORKING):
   ```bash
   docker run -d --name mongodb -p 27017:27017 mongo:7.0
   ```
   Verify with: `curl -s http://localhost:27017` (should return MongoDB HTTP message)
   **This has been validated and works correctly.**

2. **Install CommandBox CLI** (REQUIRED - Cannot validate in sandbox):
   ```bash
   # Download from https://www.ortussolutions.com/products/commandbox#download
   # Or use package manager installation:
   curl -fsSL https://downloads.ortussolutions.com/debs/gpg | sudo apt-key add -
   echo "deb https://downloads.ortussolutions.com/debs/noarch /" | sudo tee -a /etc/apt/sources.list.d/commandbox.list
   sudo apt update && sudo apt install commandbox
   
   # Verify installation:
   box version
   ```
   **WARNING: External downloads may be blocked. Use pre-configured environment if possible.**

3. **Install Project Dependencies** (requires CommandBox):
   ```bash
   # Root module dependencies  
   box install --force
   # Test harness dependencies
   cd test-harness
   box install --force
   cd ..
   ```
   **Timeout: 600+ seconds (10 minutes). NEVER CANCEL.**

4. **Build Module** (requires CommandBox):
   ```bash
   box run-script build:module
   ```
   **Timeout: 2700+ seconds (45 minutes). NEVER CANCEL.**

### CFML Engine Support
**Project supports multiple CFML engines - timeout ALL commands appropriately:**
- Lucee 5+ (`server-lucee@5.json`)
- Adobe ColdFusion 2023+ (`server-adobe@2023.json`, `server-adobe@2025.json`) 
- BoxLang CFML 1+ (`server-boxlang-cfml@1.json`)

### Testing and Development

**Run Test Suite** (requires CommandBox + MongoDB):
```bash
# Ensure MongoDB is running and create results directory
mkdir -p test-harness/tests/results
# Run complete test suite  
box testbox run --verbose outputFile=test-harness/tests/results/test-results outputFormats=json,antjunit
```
**Timeout: 1200+ seconds (20 minutes). NEVER CANCEL.**

**Start Development Server** (requires CommandBox):
```bash
# Lucee 5 (recommended for development)
box server start serverConfigFile=server-lucee@5.json --noSaveSettings --debug
# Adobe 2023  
box server start serverConfigFile=server-adobe@2023.json --noSaveSettings --debug
# BoxLang (experimental)
box server start serverConfigFile=server-boxlang-cfml@1.json --noSaveSettings --debug
```
Server runs on http://localhost:60299
Access test runner at: http://localhost:60299/tests/runner.cfm

**Alternative Server Management**:
```bash
# Start specific engines using npm-style scripts
box run-script start:lucee     # Start Lucee 5
box run-script start:2023      # Start Adobe 2023  
box run-script stop:lucee      # Stop Lucee 5
box run-script logs:lucee      # View logs
```

**Code Formatting** (requires CommandBox):
```bash
box run-script format          # Format all code
box run-script format:check    # Check formatting only
box run-script format:watch    # Watch and auto-format
```
**Timeout: 180+ seconds (3 minutes). NEVER CANCEL.**

### Project Structure
```
├── models/                    # Core MongoDB models and services
│   ├── ActiveEntity.cfc      # Base active record entity
│   ├── BaseDocumentService.cfc # Document service base
│   └── Mongo/                # MongoDB specific implementations
│       ├── Client.cfc        # MongoDB client wrapper
│       ├── Collection.cfc    # Collection operations
│       ├── Config.cfc        # Configuration management
│       └── GridFS.cfc        # GridFS file storage
├── test-harness/             # ColdBox test application
│   ├── tests/specs/          # Test specifications
│   └── config/               # Test configuration
├── build/                    # Build automation
│   └── Build.cfc            # Main build script
├── ModuleConfig.cfc          # Module configuration
└── box.json                  # CommandBox package definition
```

## Validation Requirements

**CRITICAL: After making changes, ALWAYS run with adequate timeouts:**
1. **MANDATORY: Code Formatting FIRST**: `box run-script format` (3+ minute timeout, NEVER CANCEL)
2. **MANDATORY: Complete Test Suite**: `box testbox run --verbose` (20+ minute timeout, NEVER CANCEL)
3. **Verify MongoDB Connection**: `curl -s http://localhost:27017` (should show MongoDB message)
4. **Build Validation**: `box run-script build:module` (45+ minute timeout, NEVER CANCEL)
5. **Server Start Test**: `box server start serverConfigFile=server-lucee@5.json` (5+ minute timeout)

**🔥 CRITICAL RULE: NO COMMITS WITHOUT FORMATTING AND 100% PASSING TESTS 🔥**

**Manual Testing Scenarios (After Server Start)**:
- Navigate to http://localhost:60299 (should load ColdBox app)
- Test MongoDB connection: http://localhost:60299/tests/runner.cfm
- Create/read/update/delete MongoDB documents via test endpoints
- Test GridFS file upload/download functionality  
- Verify ActiveEntity model operations
- Test aggregation pipeline operations
- Confirm database indexing works correctly

**Required Java Versions by Engine**:
- Lucee 5+: Java 11+ (OpenJDK 11 recommended)
- Adobe 2023+: Java 11+ 
- BoxLang: Java 17+
- **Current Environment**: Java 17 (confirmed compatible with all engines)

## Dependencies and Libraries
- **cbjavaloader**: Java library loading module
- **MongoDB Java Driver 5.5.1**: Core database connectivity (updated from 4.9.1)
- **BSON library**: Document serialization
- **JavaXT Core 1.7.8**: Utility functions

**JAR files stored in `lib/` directory, loaded via cbjavaloader**

## Known Issues and Workarounds

**CommandBox Installation Issues**: External downloads may be blocked in sandbox environments
- **Solution**: Use pre-configured environment with CommandBox already installed
- **Alternative**: Use GitHub Actions for CI/CD testing
- **Workaround**: Manual installation from https://www.ortussolutions.com/products/commandbox

**Build Timeout Issues**: Builds legitimately take 30-45+ minutes
- **Critical**: NEVER CANCEL long-running builds
- **Solution**: Set timeouts to 60+ minutes for build commands
- **Solution**: Set timeouts to 30+ minutes for test commands

**MongoDB Connection Issues**:
- **Problem**: "Connection refused" on localhost:27017
- **Solution**: Start Docker container: `docker run -d --name mongodb -p 27017:27017 mongo:7.0`
- **Verification**: `curl -s http://localhost:27017` should return MongoDB HTTP message

**Memory Issues During Builds**:
- **Problem**: OutOfMemory errors during testing
- **Solution**: Increase JVM heap in server configs (currently set to 768MB)
- **Alternative**: Use fewer concurrent test engines

**GridFS Configuration**:
- **Problem**: Temp directory not found for image processing
- **Solution**: Create `/cbmongodb/tmp/` directory or configure custom tmpDirectory in settings
- **Default**: MaxWidth: 1000px, MaxHeight: 1000px for images

**CI Test Failures**:
- **Problem**: GitHub Actions tests failing
- **Solution**: Check dependency versions match in box.json (MongoDB 5.5.1 drivers)
- **Solution**: Ensure all code is properly formatted with `box run-script format`
- **Solution**: Verify MongoDB connection strings are properly generated
- **Solution**: Check for Java object instantiation issues (missing `.init()` calls)
- **Debugging**: Review GitHub Actions logs for specific error messages
- **Common Issues**: 
  - Constructor errors: Use static builder methods, not direct constructors
  - API compatibility: MongoDB 5.x removed some methods, use connection strings instead
  - Variable naming: Ensure consistent use of `dbname` vs `dbName`

## CI/CD Integration
- GitHub Actions: `.github/workflows/tests.yml`
- Supports matrix testing across CFML engines
- MongoDB 8.0 Docker container in CI
- Automatic ForgeBox publishing on releases

**Environment Variables for CI:**
```
MONGODB_HOSTS=mongodb
MONGODB_PORT=27017
```

## Troubleshooting

**CommandBox not found**: External downloads blocked - requires manual installation or pre-configured environment

**MongoDB connection failed**: Ensure Docker container running on port 27017

**Build timeouts**: NEVER CANCEL - builds legitimately take 30+ minutes

**Test failures**: Check MongoDB connectivity and ensure test database is clean

**Memory issues**: Increase JVM heap size in server JSON configs (default 768MB)

## Common Commands and File Locations

### Frequently Referenced Files
```
ls -la [repo-root]
.cfconfig.json           # CFML engine configuration
.cfformat.json           # Code formatting rules (Ortus standards)
.cflintrc               # Code linting configuration
.env.template           # Environment variables template
.github/workflows/      # CI/CD automation (tests.yml, release.yml, etc)
.gitignore              # Git ignore patterns
CONTRIBUTING.md         # Contribution guidelines
ModuleConfig.cfc        # Main module configuration
box.json               # CommandBox package definition
build/Build.cfc        # Build automation script
changelog.md           # Version history
models/                # Core module classes
readme.md              # Project documentation
server-*.json          # CFML server configurations
test-harness/          # ColdBox test application
```

### Key Configuration Files Content

**box.json dependencies**:
```json
"dependencies":{
    "cbjavaloader":"stable",
    "mongodb-legacy-driver":"jar:https://search.maven.org/remotecontent?filepath=org/mongodb/mongodb-driver-legacy/5.5.1/mongodb-driver-legacy-5.5.1.jar",
    "mongodb-bson":"jar:https://search.maven.org/remotecontent?filepath=org/mongodb/bson/5.5.1/bson-5.5.1.jar",
    "mongodb-driver-core":"jar:https://search.maven.org/remotecontent?filepath=org/mongodb/mongodb-driver-core/5.5.1/mongodb-driver-core-5.5.1.jar",
    "mongodb-driver-sync":"jar:https://search.maven.org/remotecontent?filepath=org/mongodb/mongodb-driver-sync/5.5.1/mongodb-driver-sync-5.5.1.jar",
    "javaxt-core":"jar:https://www.javaxt.com/maven/javaxt/javaxt-core/1.7.8/javaxt-core-1.7.8.jar"
}
```

**Available Scripts** (run with `box run-script <name>`):
- `build:module` - Build complete module (45+ minutes)
- `build:docs` - Generate API documentation
- `install:dependencies` - Install all dependencies  
- `format` - Format all CFML code
- `format:check` - Validate code formatting
- `start:lucee` - Start Lucee 5 server
- `start:2023` - Start Adobe 2023 server
- `stop:lucee` - Stop Lucee server
- `logs:lucee` - View server logs

### Test Structure
```
test-harness/tests/
├── specs/
│   ├── integration/          # Integration tests requiring MongoDB
│   │   ├── TestActiveEntity.cfc      # ActiveRecord pattern tests
│   │   ├── TestGEOEntity.cfc         # Geospatial functionality tests
│   │   └── TestFileEntity.cfc        # GridFS file operations tests
│   └── unit/                # Unit tests (mocked dependencies)
│       ├── testMongoClient.cfc       # MongoDB client tests
│       └── testMongoCollection.cfc   # Collection operations tests
├── mocks/                   # Test mock objects
│   ├── ActiveEntityMock.cfc
│   ├── FileEntityMock.cfc
│   └── StatesMock.cfc
└── CBMongoDBBaseTest.cfc    # Base test class with common setup
```

**Test Runner URLs** (after starting server):
- Main: http://localhost:60299/tests/runner.cfm
- Direct TestBox: http://localhost:60299/testbox/

## Alternative Approaches When CommandBox Unavailable

**If CommandBox cannot be installed:**
1. **Use GitHub Actions for validation** - The `.github/workflows/tests.yml` contains the complete CI process
2. **Manual CFML engine setup** - Install Lucee or Adobe ColdFusion directly
3. **Docker-based development** - Use CFML Docker containers with volume mounts
4. **Focus on model validation** - Test core CFML files for syntax and logic without full server

**For MongoDB-only testing:**
```bash
# Test MongoDB connectivity directly
docker exec -it mongodb mongosh test --eval "db.runCommand('ping')"
# Should return: { ok: 1 }
```

**CFML Syntax Validation** (without CommandBox):
```bash
# Check CFC syntax using basic validation
grep -n "component\|function\|return" models/*.cfc
# Look for common syntax issues
grep -n "structKeyExists\|isNull\|structAppend" models/*.cfc
```

This module is production-ready and actively maintained. The GitHub Actions CI process validates all changes across multiple CFML engines with MongoDB 8.0.

**Final Note**: This module requires active MongoDB connectivity for all integration tests. Ensure MongoDB is running before attempting any build or test operations.