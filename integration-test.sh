#!/usr/bin/env bash

# Simple integration test that can be run locally
# This test focuses on the most common use cases

set -e -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Docker Volume Snapshot - Integration Test${NC}"
echo "==========================================="

cleanup() {
    echo "Cleaning up..."
    docker volume rm integration_test_volume integration_restore_volume 2>/dev/null || true
    rm -f integration_test.tar integration_test.tar.gz 2>/dev/null || true
    echo "Cleanup complete"
}

trap cleanup EXIT

# Make sure the script is executable
chmod +x ./docker-volume-snapshot

echo -e "${YELLOW}Step 1: Creating test volume with sample data${NC}"
docker volume create integration_test_volume
docker run --rm -v integration_test_volume:/data busybox sh -c '
    echo "Hello, World!" > /data/hello.txt
    echo "Integration test data" > /data/test.txt
    mkdir -p /data/subdir
    echo "Nested file content" > /data/subdir/nested.txt
    echo "File with special chars: áéíóú" > /data/special.txt
'

echo -e "${YELLOW}Step 2: Creating snapshot (uncompressed)${NC}"
./docker-volume-snapshot create integration_test_volume integration_test.tar

echo -e "${YELLOW}Step 3: Creating snapshot (compressed)${NC}"
./docker-volume-snapshot create integration_test_volume integration_test.tar.gz

echo -e "${YELLOW}Step 4: Verifying snapshot files exist${NC}"
ls -lh integration_test.tar integration_test.tar.gz

echo -e "${YELLOW}Step 5: Restoring from uncompressed snapshot${NC}"
docker volume create integration_restore_volume
./docker-volume-snapshot restore integration_test.tar integration_restore_volume

echo -e "${YELLOW}Step 6: Verifying restored data${NC}"
echo "Checking hello.txt..."
restored_hello=$(docker run --rm -v integration_restore_volume:/data busybox cat /data/hello.txt)
if [[ "$restored_hello" == "Hello, World!" ]]; then
    echo -e "${GREEN}✓ hello.txt restored correctly${NC}"
else
    echo -e "${RED}✗ hello.txt not restored correctly${NC}"
    exit 1
fi

echo "Checking nested file..."
restored_nested=$(docker run --rm -v integration_restore_volume:/data busybox cat /data/subdir/nested.txt)
if [[ "$restored_nested" == "Nested file content" ]]; then
    echo -e "${GREEN}✓ Nested file restored correctly${NC}"
else
    echo -e "${RED}✗ Nested file not restored correctly${NC}"
    exit 1
fi

echo "Checking special characters..."
restored_special=$(docker run --rm -v integration_restore_volume:/data busybox cat /data/special.txt)
if [[ "$restored_special" == "File with special chars: áéíóú" ]]; then
    echo -e "${GREEN}✓ Special characters preserved${NC}"
else
    echo -e "${RED}✗ Special characters not preserved${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 7: Testing compressed snapshot restore${NC}"
docker volume rm integration_restore_volume
docker volume create integration_restore_volume
./docker-volume-snapshot restore integration_test.tar.gz integration_restore_volume

echo "Verifying compressed restore..."
restored_test=$(docker run --rm -v integration_restore_volume:/data busybox cat /data/test.txt)
if [[ "$restored_test" == "Integration test data" ]]; then
    echo -e "${GREEN}✓ Compressed snapshot restored correctly${NC}"
else
    echo -e "${RED}✗ Compressed snapshot not restored correctly${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 All integration tests passed!${NC}"
echo "The docker-volume-snapshot utility is working correctly."