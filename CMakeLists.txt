# Set minimum CMake version
cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

# Make GENERATED source-file property visible across directory scopes
# so consumer targets defined in other directories can compile xxd_embed outputs.
if(POLICY CMP0118)
    cmake_policy(SET CMP0118 NEW)
endif()

# Project definition
project(xxd VERSION 1.0.0 LANGUAGES C)

# Options to build
option(XXD_BUILD_STATIC "Build static library" ON)
option(XXD_BUILD_EXAMPLE "Build example executable" ON)

# Configure C standard to C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Build the xxd host tool or locate it — must run on the build machine, not the target device.
if(CMAKE_CROSSCOMPILING)
    # When cross-compiling (e.g. Android NDK), xxd cannot be compiled for the host here.
    # Require an existing xxd installation on the build machine.
    find_program(XXD_HOST_EXECUTABLE xxd)
    if(NOT XXD_HOST_EXECUTABLE)
        message(FATAL_ERROR
            "Cross-compiling requires xxd to be installed on the build host.\n"
            "  Debian/Ubuntu: sudo apt install xxd\n"
            "  macOS:         brew install vim\n"
            "  Windows (WSL): sudo apt install xxd")
    endif()
    set(XXD_TOOL_CMD "${XXD_HOST_EXECUTABLE}")
    set(XXD_TOOL_DEPS "")
else()
    add_executable(xxd ${CMAKE_CURRENT_SOURCE_DIR}/src/xxd.c)
    set(XXD_TOOL_CMD $<TARGET_FILE:xxd>)
    set(XXD_TOOL_DEPS xxd)
endif()

# Build static library for xxd functionality
if(${XXD_BUILD_STATIC})
	add_library(libxxd STATIC)
else()
	add_library(libxxd SHARED)
endif()

# Add source files for the library, including the embedding logic and headers
target_sources(libxxd PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/xxd_embed.c
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd.h
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd.in
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/EmbedFile.cmake)

# Propagate XXD_STATIC so consumers skip dllimport decorators
if(${XXD_BUILD_STATIC})
    target_compile_definitions(libxxd PUBLIC XXD_STATIC)
endif()

# Set C standard for library
set_property(TARGET libxxd PROPERTY C_STANDARD 11)

# Add public include directory
target_include_directories(libxxd PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Set output library name
set_target_properties(libxxd PROPERTIES OUTPUT_NAME xxd)

# Create namespace alias for the library
add_library(xxd::xxd ALIAS libxxd)

# Cache the include directory path for use in macros
set(CMAKE_CURRENT_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include" CACHE STRING "" FORCE)

# Macro: Convert file into a binary blob and embed it into a C source file
macro(xxd_embed FILE_KEY FILE_PATH SOURCES)
    # Translate file content into comma-separated hex byte codes
    set(FILE_HEX "${CMAKE_CURRENT_BINARY_DIR}/${FILE_KEY}.hex")

    # Generate hex file using xxd utility
    add_custom_command(
        OUTPUT ${FILE_HEX}
        COMMAND ${XXD_TOOL_CMD} -i < ${FILE_PATH} > ${FILE_HEX}
        COMMENT "Generating hex representation of ${FILE_PATH} file content"
        DEPENDS ${FILE_PATH} ${XXD_TOOL_DEPS})
    set_source_files_properties("${FILE_HEX}" PROPERTIES GENERATED TRUE)

    # Generate C source file embedding the hex content
    set(EMBED_FILE_PATH "${CMAKE_CURRENT_BINARY_DIR}/${FILE_KEY}.c")
    add_custom_command(
        OUTPUT ${EMBED_FILE_PATH}
        COMMAND ${CMAKE_COMMAND} -DCMAKE_CURRENT_INCLUDE_DIR=${CMAKE_CURRENT_INCLUDE_DIR} -DFILE_HEX=${FILE_HEX} -DFILE_KEY=${FILE_KEY} -DFILE_PATH=${FILE_PATH} -DEMBED_FILE_PATH=${EMBED_FILE_PATH} -P ${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/EmbedFile.cmake
        COMMENT "Embedding file ${FILE_PATH}"
        DEPENDS ${FILE_HEX} "${CMAKE_CURRENT_INCLUDE_DIR}/xxd.in")
    set_source_files_properties("${EMBED_FILE_PATH}" PROPERTIES GENERATED TRUE)

    # Add generated source file to compilation list
    list(APPEND ${SOURCES} ${EMBED_FILE_PATH})

    # Use debug flags to speed up compilation of large embedded files
    set_source_files_properties(${EMBED_FILE_PATH} PROPERTIES COMPILE_FLAGS ${CMAKE_C_FLAGS_DEBUG})

    message(STATUS "Source file ${EMBED_FILE_PATH} shall be added to ${SOURCES}")
endmacro()

# Build example subdirectory
if(${XXD_BUILD_EXAMPLE})
    add_subdirectory(example)
endif()
