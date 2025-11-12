#!/bin/bash

# Build script for Depth project

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Building Depth Camera Project${NC}"
echo -e "${GREEN}========================================${NC}"

# Parse arguments
BUILD_TYPE="${1:-Release}"
CLEAN="${2}"

echo -e "${YELLOW}Build type: ${BUILD_TYPE}${NC}"

# Create build directory
BUILD_DIR="build"

if [ "$CLEAN" == "clean" ]; then
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
echo -e "${YELLOW}Configuring CMake...${NC}"
cmake .. \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_TESTS=ON \
    -DBUILD_EXAMPLES=ON \
    -DENABLE_OPENMP=ON

# Build
echo -e "${YELLOW}Building...${NC}"
make -j$(nproc)

# Test (if enabled)
if [ -f "CTestTestfile.cmake" ]; then
    echo -e "${YELLOW}Running tests...${NC}"
    ctest --output-on-failure
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
