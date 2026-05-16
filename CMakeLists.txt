# Set minimum CMake version
cmake_minimum_required(VERSION 3.1)

# Project definition
project(xxd)

# Option to build example executable
option(XXD_BUILD_EXAMPLE "Build example executable" ON)

# Configure C++ standard to C++11
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build xxd command-line utility from C source
add_executable(xxd ${CMAKE_CURRENT_SOURCE_DIR}/src/xxd.c)

# Build shared library for xxd functionality
add_library(libxxd SHARED
    ${CMAKE_CURRENT_SOURCE_DIR}/src/xxd.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd.h
	${CMAKE_CURRENT_SOURCE_DIR}/include/xxd.in
	${CMAKE_CURRENT_SOURCE_DIR}/cmake/EmbedFile.cmake)

# Set C++ standard for library
set_property(TARGET libxxd PROPERTY CXX_STANDARD 11)

# Add public include directory
target_include_directories(libxxd PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Set output library name
set_target_properties(libxxd PROPERTIES OUTPUT_NAME xxd)

# Create namespace alias for the library
add_library(xxd::xxd ALIAS libxxd)

# Cache the include directory path for use in macros
set(CMAKE_CURRENT_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include" CACHE STRING "" FORCE)

# Macro: Convert file into a binary blob and embed it into a C++ source file
macro(xxd_embed FILE_KEY FILE_PATH SOURCES)
	# Translate file content into comma-separated hex byte codes
	set(FILE_HEX "${CMAKE_CURRENT_BINARY_DIR}/${FILE_KEY}.hex")

	# Generate hex file using xxd utility
	add_custom_command(
		OUTPUT ${FILE_HEX}
		COMMAND $<TARGET_FILE:xxd> -i < ${FILE_PATH} > ${FILE_HEX}
		COMMENT "Generating hex representation of ${FILE_PATH} file content"
		DEPENDS ${FILE_PATH} xxd)
	set_source_files_properties("${FILE_HEX}" PROPERTIES GENERATED TRUE)

	# Generate C++ source file embedding the hex content
	set(EMBED_FILE_PATH "${CMAKE_CURRENT_BINARY_DIR}/${FILE_KEY}.cpp")
	add_custom_command(
		OUTPUT ${EMBED_FILE_PATH}
		COMMAND ${CMAKE_COMMAND} -DCMAKE_CURRENT_INCLUDE_DIR=${CMAKE_CURRENT_INCLUDE_DIR} -DFILE_HEX=${FILE_HEX} -DFILE_KEY=${FILE_KEY} -DFILE_PATH=${FILE_PATH} -DEMBED_FILE_PATH=${EMBED_FILE_PATH} -P ${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/EmbedFile.cmake
		COMMENT "Embedding file ${FILE_PATH}"
		DEPENDS ${FILE_HEX} "${CMAKE_CURRENT_INCLUDE_DIR}/xxd.in")
	set_source_files_properties("${EMBED_FILE_PATH}" PROPERTIES GENERATED TRUE)

	# Add generated source file to compilation list
	list(APPEND ${SOURCES} ${EMBED_FILE_PATH})

	# Use debug flags to speed up compilation of large embedded files
	set_source_files_properties(${EMBED_FILE_PATH} PROPERTIES COMPILE_FLAGS ${CMAKE_CXX_FLAGS_DEBUG})

	message(STATUS "Source file ${EMBED_FILE_PATH} shall be added to ${SOURCES}")
endmacro()

# Build example subdirectory
if(${XXD_BUILD_EXAMPLE})
	add_subdirectory(example)
endif()
