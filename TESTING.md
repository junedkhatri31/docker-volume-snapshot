# Testing Docker Volume Snapshot

This document describes the testing infrastructure for the `docker-volume-snapshot` utility.

## Test Files

### 1. `test.sh` - Comprehensive Test Suite
A comprehensive test suite that covers all functionality including:
- Creating snapshots in current directory
- Creating snapshots in non-current directory  
- Creating snapshots with absolute paths
- Creating compressed snapshots (.tar.gz, .tar.bz2, .tar.xz)
- Restoring snapshots from current directory
- Restoring snapshots from non-current directory
- Restoring snapshots from absolute paths
- Restoring compressed snapshots
- Error handling for invalid commands and missing arguments
- Error handling for non-existent volumes and files

### 2. `integration-test.sh` - Quick Integration Test
A simpler integration test that focuses on the most common use cases:
- Creating a test volume with sample data
- Creating both compressed and uncompressed snapshots
- Restoring snapshots and verifying data integrity
- Testing special characters and nested directories

## GitHub Actions Workflows

### 1. `quick-test.yml` - Fast Feedback
- Runs on every push and pull request
- Executes the integration test for quick feedback
- Validates script syntax

### 2. `test.yml` - Main Test Suite
- Runs the comprehensive test suite
- Includes additional smoke tests
- Runs on pushes to main/develop branches

### 3. `test-matrix.yml` - Comprehensive Testing
- Tests across multiple Ubuntu versions (20.04, 22.04, latest)
- Tests different Docker versions
- Includes performance testing
- Tests various compression formats
- Tests edge cases (special characters, spaces in paths)
- Runs daily via cron schedule

## Running Tests Locally

### Prerequisites
- Docker installed and running
- Bash shell
- The `docker-volume-snapshot` script in the current directory

### Quick Test
```bash
# Run the integration test
./integration-test.sh
```

### Full Test Suite
```bash
# Run all tests
./test.sh
```

### Manual Testing
```bash
# Test basic functionality
docker volume create my_test_volume
docker run --rm -v my_test_volume:/data busybox sh -c 'echo "test data" > /data/test.txt'

# Create snapshot
./docker-volume-snapshot create my_test_volume my_snapshot.tar

# Restore to new volume
docker volume create my_restored_volume
./docker-volume-snapshot restore my_snapshot.tar my_restored_volume

# Verify data
docker run --rm -v my_restored_volume:/data busybox cat /data/test.txt

# Cleanup
docker volume rm my_test_volume my_restored_volume
rm my_snapshot.tar
```

## Test Coverage

The test suite covers:

### Core Functionality
- ✅ Volume snapshot creation
- ✅ Volume snapshot restoration
- ✅ Compressed and uncompressed formats
- ✅ Current and non-current directory operations
- ✅ Absolute path handling

### Edge Cases
- ✅ Special characters in file names
- ✅ Nested directory structures
- ✅ Spaces in file paths
- ✅ Various compression formats (.tar, .tar.gz, .tar.bz2, .tar.xz)
- ✅ Large volumes (performance testing)

### Error Handling
- ✅ Invalid commands
- ✅ Missing arguments
- ✅ Non-existent volumes
- ✅ Non-existent snapshot files
- ✅ Invalid paths

### Docker Integration
- ✅ Docker volume operations
- ✅ Container-based file operations
- ✅ Volume cleanup
- ✅ Cross-platform compatibility

## Test Data

The tests use various types of test data:
- Simple text files
- Files with special characters (áéíóú)
- Nested directory structures
- Multiple files for performance testing
- Binary-like content simulation

## Continuous Integration

The GitHub Actions workflows ensure:
- Tests run on every code change
- Multiple operating system versions are tested
- Different Docker versions are validated
- Performance regressions are caught
- Edge cases are continuously verified

## Adding New Tests

To add new tests:

1. **For quick feedback**: Add to `integration-test.sh`
2. **For comprehensive coverage**: Add to `test.sh`
3. **For specific scenarios**: Add to `test-matrix.yml`

Follow the existing patterns:
- Use descriptive test names
- Include both positive and negative test cases
- Clean up resources after tests
- Provide clear success/failure feedback