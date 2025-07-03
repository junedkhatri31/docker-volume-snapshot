#!/usr/bin/env bash

set -e -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test utilities
print_test_header() {
    echo -e "${YELLOW}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++)) || true
    ((TESTS_TOTAL++)) || true
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++)) || true
    ((TESTS_TOTAL++)) || true
}

cleanup() {
    echo "Cleaning up test resources..."
    
    # Remove test volumes
    docker volume rm test_volume_1 test_volume_2 test_volume_3 test_volume_4 2>/dev/null || true
    
    # Remove test files
    rm -f test_snapshot.tar test_snapshot.tar.gz 2>/dev/null || true
    rm -f /tmp/test_snapshot.tar /tmp/test_snapshot.tar.gz 2>/dev/null || true
    rm -rf test_output_dir 2>/dev/null || true
    
    echo "Cleanup complete"
}

# Set up cleanup trap only for interruption
trap cleanup INT TERM

# Ensure docker-volume-snapshot is executable
chmod +x ./docker-volume-snapshot

print_test_header "Setting up test environment"

# Create test volumes with sample data
docker volume create test_volume_1
docker volume create test_volume_2
docker volume create test_volume_3
docker volume create test_volume_4

# Add sample data to test volumes
docker run --rm -v test_volume_1:/data busybox sh -c 'echo "test data 1" > /data/file1.txt && echo "more data" > /data/file2.txt'
docker run --rm -v test_volume_2:/data busybox sh -c 'echo "test data 2" > /data/file1.txt && mkdir -p /data/subdir && echo "nested data" > /data/subdir/nested.txt'

print_test_header "Test 1: Create snapshot in current directory"

# Test creating snapshot in current directory
if ./docker-volume-snapshot create test_volume_1 test_snapshot.tar; then
    if [[ -f "test_snapshot.tar" ]]; then
        print_success "Created snapshot in current directory"
    else
        print_failure "Snapshot file not created in current directory"
    fi
else
    print_failure "Failed to create snapshot in current directory"
fi

print_test_header "Test 2: Create snapshot in non-current directory"

# Create output directory
mkdir -p test_output_dir

# Test creating snapshot in non-current directory
if ./docker-volume-snapshot create test_volume_2 test_output_dir/test_snapshot.tar; then
    if [[ -f "test_output_dir/test_snapshot.tar" ]]; then
        print_success "Created snapshot in non-current directory"
    else
        print_failure "Snapshot file not created in non-current directory"
    fi
else
    print_failure "Failed to create snapshot in non-current directory"
fi

print_test_header "Test 3: Create compressed snapshot (.tar.gz)"

# Test creating compressed snapshot
if ./docker-volume-snapshot create test_volume_1 test_snapshot.tar.gz; then
    if [[ -f "test_snapshot.tar.gz" ]]; then
        print_success "Created compressed snapshot"
    else
        print_failure "Compressed snapshot file not created"
    fi
else
    print_failure "Failed to create compressed snapshot"
fi

print_test_header "Test 4: Create snapshot with absolute path"

# Test creating snapshot with absolute path
if ./docker-volume-snapshot create test_volume_2 /tmp/test_snapshot.tar; then
    if [[ -f "/tmp/test_snapshot.tar" ]]; then
        print_success "Created snapshot with absolute path"
    else
        print_failure "Snapshot file not created with absolute path"
    fi
else
    print_failure "Failed to create snapshot with absolute path"
fi

print_test_header "Test 5: Restore snapshot from current directory"

# Test restoring snapshot from current directory
if ./docker-volume-snapshot restore test_snapshot.tar test_volume_3; then
    # Verify the restored data
    restored_data=$(docker run --rm -v test_volume_3:/data busybox cat /data/file1.txt)
    if [[ "$restored_data" == "test data 1" ]]; then
        print_success "Restored snapshot from current directory"
    else
        print_failure "Restored data doesn't match original (got: '$restored_data')"
    fi
else
    print_failure "Failed to restore snapshot from current directory"
fi

print_test_header "Test 6: Restore snapshot from non-current directory"

# Test restoring snapshot from non-current directory
if ./docker-volume-snapshot restore test_output_dir/test_snapshot.tar test_volume_4; then
    # Verify the restored data
    restored_data=$(docker run --rm -v test_volume_4:/data busybox cat /data/file1.txt)
    restored_nested=$(docker run --rm -v test_volume_4:/data busybox cat /data/subdir/nested.txt)
    if [[ "$restored_data" == "test data 2" && "$restored_nested" == "nested data" ]]; then
        print_success "Restored snapshot from non-current directory"
    else
        print_failure "Restored data doesn't match original"
    fi
else
    print_failure "Failed to restore snapshot from non-current directory"
fi

print_test_header "Test 7: Restore compressed snapshot"

# Create a fresh volume for compressed restore test
docker volume rm test_volume_3 2>/dev/null || true
docker volume create test_volume_3

# Test restoring compressed snapshot
if ./docker-volume-snapshot restore test_snapshot.tar.gz test_volume_3; then
    # Verify the restored data
    restored_data=$(docker run --rm -v test_volume_3:/data busybox cat /data/file1.txt)
    if [[ "$restored_data" == "test data 1" ]]; then
        print_success "Restored compressed snapshot"
    else
        print_failure "Restored compressed data doesn't match original"
    fi
else
    print_failure "Failed to restore compressed snapshot"
fi

print_test_header "Test 8: Restore snapshot from absolute path"

# Create a fresh volume for absolute path restore test
docker volume rm test_volume_3 2>/dev/null || true
docker volume create test_volume_3

# Test restoring snapshot from absolute path
if ./docker-volume-snapshot restore /tmp/test_snapshot.tar test_volume_3; then
    # Verify the restored data
    restored_data=$(docker run --rm -v test_volume_3:/data busybox cat /data/file1.txt)
    restored_nested=$(docker run --rm -v test_volume_3:/data busybox cat /data/subdir/nested.txt)
    if [[ "$restored_data" == "test data 2" && "$restored_nested" == "nested data" ]]; then
        print_success "Restored snapshot from absolute path"
    else
        print_failure "Restored data from absolute path doesn't match original"
    fi
else
    print_failure "Failed to restore snapshot from absolute path"
fi

print_test_header "Test 9: Error handling - missing arguments"

# Test error handling for create command
set +e  # Temporarily disable exit on error
./docker-volume-snapshot create 2>/dev/null
if [[ $? -eq 0 ]]; then
    print_failure "Should have failed with missing arguments for create"
else
    print_success "Properly handled missing arguments for create"
fi

# Test error handling for restore command
./docker-volume-snapshot restore 2>/dev/null
if [[ $? -eq 0 ]]; then
    print_failure "Should have failed with missing arguments for restore"
else
    print_success "Properly handled missing arguments for restore"
fi
set -e  # Re-enable exit on error

print_test_header "Test 10: Error handling - invalid command"

# Test error handling for invalid command
if ./docker-volume-snapshot invalid_command 2>/dev/null; then
    print_failure "Should have failed with invalid command"
else
    print_success "Properly handled invalid command"
fi

print_test_header "Test 11: Error handling - non-existent snapshot file"

# Test error handling for non-existent snapshot file
if ./docker-volume-snapshot restore non_existent_snapshot.tar test_volume_1 2>/dev/null; then
    print_failure "Should have failed with non-existent snapshot file"
else
    print_success "Properly handled non-existent snapshot file"
fi

# Clean up test resources
cleanup

print_test_header "Test Results Summary"

echo "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi