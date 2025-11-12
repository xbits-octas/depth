cmake_minimum_required(VERSION 3.16)

# Read version from VERSION file
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" VERSION_STRING)
string(STRIP "${VERSION_STRING}" VERSION_STRING)
string(REPLACE "." ";" VERSION_LIST ${VERSION_STRING})
list(GET VERSION_LIST 0 VERSION_MAJOR)
list(GET VERSION_LIST 1 VERSION_MINOR)
list(GET VERSION_LIST 2 VERSION_PATCH)

project(depth
    VERSION ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
    LANGUAGES CXX C
    DESCRIPTION "Depth Camera Algorithm Project with Stereo + Structured Light + RGB"
)

message(STATUS "Building ${PROJECT_NAME} version ${PROJECT_VERSION}")

# C++ Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Options
option(BUILD_TESTS "Build test programs" ON)
option(BUILD_EXAMPLES "Build example programs" ON)
option(ENABLE_OPENMP "Enable OpenMP for parallel processing" ON)
option(ENABLE_DPU "Enable DPU hardware acceleration" OFF)
option(ENABLE_NPU "Enable NPU for AI inference" OFF)

# Find packages
find_package(OpenCV 4.0 REQUIRED)
find_package(Eigen3 REQUIRED)

# Optional packages
if(ENABLE_OPENMP)
    find_package(OpenMP)
    if(OpenMP_CXX_FOUND)
        message(STATUS "OpenMP found")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    endif()
endif()

# ONNX Runtime (optional)
find_package(onnxruntime QUIET)
if(onnxruntime_FOUND)
    message(STATUS "ONNX Runtime found")
    set(ENABLE_ONNX ON)
else()
    message(STATUS "ONNX Runtime not found, AI inference disabled")
    set(ENABLE_ONNX OFF)
endif()

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${OpenCV_INCLUDE_DIRS}
    ${EIGEN3_INCLUDE_DIRS}
)

# Generate version header
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/include/depth/version.h.in"
    "${CMAKE_CURRENT_BINARY_DIR}/include/depth/version.h"
)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)

# Source files
set(DEPTH_SOURCES
    # Core algorithms (to be implemented)
    # src/core/stereo.cpp
    # src/core/structured_light.cpp
    # src/core/fusion.cpp
    # src/preprocessing/preprocess.cpp
    # src/postprocessing/postprocess.cpp
    # src/utils/utils.cpp
)

set(DEPTH_HEADERS
    # include/depth/core/stereo.h
    # include/depth/core/structured_light.h
    # include/depth/core/fusion.h
)

# Library target
# add_library(depth SHARED ${DEPTH_SOURCES})
# target_link_libraries(depth
#     ${OpenCV_LIBS}
#     Eigen3::Eigen
# )

# if(ENABLE_ONNX)
#     target_link_libraries(depth onnxruntime)
# endif()

# Examples
if(BUILD_EXAMPLES)
    # add_subdirectory(examples)
endif()

# Tests
if(BUILD_TESTS)
    enable_testing()
    # add_subdirectory(tests)
endif()

# Installation
# install(TARGETS depth
#     LIBRARY DESTINATION lib
#     ARCHIVE DESTINATION lib
#     RUNTIME DESTINATION bin
# )

# install(DIRECTORY include/depth
#     DESTINATION include
#     FILES_MATCHING PATTERN "*.h"
# )

# Print configuration summary
message(STATUS "========================================")
message(STATUS "  ${PROJECT_NAME} ${PROJECT_VERSION}")
message(STATUS "========================================")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  OpenCV version: ${OpenCV_VERSION}")
message(STATUS "  Build tests: ${BUILD_TESTS}")
message(STATUS "  Build examples: ${BUILD_EXAMPLES}")
message(STATUS "  OpenMP: ${OpenMP_FOUND}")
message(STATUS "  ONNX Runtime: ${ENABLE_ONNX}")
message(STATUS "  DPU support: ${ENABLE_DPU}")
message(STATUS "  NPU support: ${ENABLE_NPU}")
message(STATUS "========================================")
