# Set minimum CMake version
# 3.24 is required for $<LINK_LIBRARY:WHOLE_ARCHIVE,...> used to retain
# constructor-only translation units linked from the per-directory resource lib.
cmake_minimum_required(VERSION 3.24 FATAL_ERROR)

# Make GENERATED source-file property visible across directory scopes
# so consumer targets defined in other directories can compile xxd_embed outputs.
if(POLICY CMP0118)
    cmake_policy(SET CMP0118 NEW)
endif()

# Project definition
project(xxd VERSION 3.0.0 LANGUAGES C)

# Options to build
option(XXD_BUILD_EXECUTABLE "Build xxd as standalone executable" ON)
option(XXD_BUILD_STATIC "Build static library" ON)
option(XXD_BUILD_EXAMPLE "Build example executable" ON)

# Controls the binary embedding strategy used by xxd_embed().
# AUTO: detect from compiler (MSVC or Emscripten -> hex array, GCC/Clang -> .incbin)
# ON:   force .incbin via inline __asm__ (GCC/Clang assembler required)
# OFF:  force hex array in C (works with any C compiler, slower for large files)
set(XXD_EMBED_ASM "AUTO" CACHE STRING "Embedding strategy: AUTO (detect by compiler), ON (force .incbin), OFF (force hex array)")
set_property(CACHE XXD_EMBED_ASM PROPERTY STRINGS "AUTO" "ON" "OFF")

# Configure C standard to C11
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Build xxd executable (optional - not required for embedding functionality)
if(XXD_BUILD_EXECUTABLE AND NOT EMSCRIPTEN)
    add_executable(xxd ${CMAKE_CURRENT_SOURCE_DIR}/src/xxd.c)
    set_property(TARGET xxd PROPERTY C_STANDARD 11)
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
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd.c.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd_gas.c.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/xxd_wasm.c.in
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/EmbedFile.cmake
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateEmbed.cmake
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/GenerateWasmEmbed.cmake)

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

# Cache the include directory path for use in functions
set(CMAKE_CURRENT_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include" CACHE STRING "" FORCE)

# Cache the binary directory of this submodule so xxd_embed writes its generated
# .hex/.c files here, not in the caller's CMAKE_CURRENT_BINARY_DIR. Consumers may
# override XXD_EMBED_BINARY_DIR before calling xxd_embed to redirect output elsewhere.
set(XXD_EMBED_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE PATH "Directory for xxd_embed generated files")

# Deferred finalizer: creates a per-directory static lib from accumulated embed sources
# and links it to every target registered via xxd_embed(... TARGETS ...).
function(_xxd_create_resource_lib)
    get_property(_sources DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        PROPERTY _XXD_PENDING_SOURCES)
    get_property(_targets DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        PROPERTY _XXD_PENDING_TARGETS)

    if(NOT _sources)
        return()
    endif()

    # Derive a stable unique name from the directory path hash.
    string(SHA256 _dir_hash "${CMAKE_CURRENT_SOURCE_DIR}")
    string(SUBSTRING "${_dir_hash}" 0 16 _dir_hash_short)
    set(_lib_name "xxd_resources_${_dir_hash_short}")

    list(REMOVE_DUPLICATES _targets)

    add_library(${_lib_name} STATIC ${_sources})
    target_link_libraries(${_lib_name} PUBLIC xxd::xxd)

    # Wrap in WHOLE_ARCHIVE so the linker keeps translation units whose only
    # exports are global constructors registering resources at startup.
    foreach(_target IN LISTS _targets)
        get_target_property(_type ${_target} TYPE)
        if(_type STREQUAL "INTERFACE_LIBRARY")
            # INTERFACE libraries propagate the resource lib to downstream consumers.
            target_link_libraries(${_target} INTERFACE
                "$<LINK_LIBRARY:WHOLE_ARCHIVE,${_lib_name}>")
        else()
            target_link_libraries(${_target} PRIVATE
                "$<LINK_LIBRARY:WHOLE_ARCHIVE,${_lib_name}>")
            add_dependencies(${_target} ${_lib_name})
        endif()
    endforeach()

    # For Emscripten: apply accumulated --embed-file flags so emcc bundles raw files
    # into the JS/WASM output, making them accessible via the virtual FS at runtime.
    if(EMSCRIPTEN)
        foreach(_target IN LISTS _targets)
            get_property(_embed_files DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                PROPERTY "_XXD_EMBED_FILES_${_target}")
            get_target_property(_type ${_target} TYPE)
            foreach(_ef IN LISTS _embed_files)
                if(_type STREQUAL "INTERFACE_LIBRARY")
                    target_link_options(${_target} INTERFACE "SHELL:--embed-file ${_ef}")
                else()
                    target_link_options(${_target} PRIVATE "SHELL:--embed-file ${_ef}")
                endif()
            endforeach()
        endforeach()
    endif()
endfunction()

# Function: Embed a binary file into the consuming targets as a registered resource.
#   FILE_KEY  (required) - lookup key passed to xxd_add()
#   FILE_PATH (required) - absolute path to the file to embed
#   MIME      (required) - MIME type string
#   TARGETS   (required) - one or more targets that will consume the embedded data
function(xxd_embed)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "FILE_KEY;FILE_PATH;MIME" "TARGETS")

    if(NOT ARG_FILE_KEY)
        message(FATAL_ERROR "xxd_embed: FILE_KEY is required")
    endif()
    if(NOT ARG_FILE_PATH)
        message(FATAL_ERROR "xxd_embed: FILE_PATH is required")
    endif()
    if(NOT ARG_MIME)
        message(FATAL_ERROR "xxd_embed: MIME is required")
    endif()
    if(NOT ARG_TARGETS)
        message(FATAL_ERROR "xxd_embed: TARGETS is required")
    endif()

    # Resolve embedding strategy.
    if(XXD_EMBED_ASM STREQUAL "AUTO")
        if(MSVC OR EMSCRIPTEN)
            set(_use_asm FALSE)
        else()
            set(_use_asm TRUE)
        endif()
    elseif(XXD_EMBED_ASM STREQUAL "ON")
        if(EMSCRIPTEN)
            message(FATAL_ERROR "xxd_embed: XXD_EMBED_ASM=ON is not supported with Emscripten (wasm-ld has no .incbin). Use AUTO or OFF.")
        endif()
        set(_use_asm TRUE)
    else()
        set(_use_asm FALSE)
    endif()

    file(MAKE_DIRECTORY "${XXD_EMBED_BINARY_DIR}/Generated")
    set(_embed_c "${XXD_EMBED_BINARY_DIR}/Generated/${ARG_FILE_KEY}.c")

    if(EMSCRIPTEN AND NOT _use_asm)
        # Emscripten path: embed via --embed-file linker flag + fopen at startup.
        # No hex conversion needed; the raw file is bundled by emcc into the JS output.
        add_custom_command(
            OUTPUT "${_embed_c}"
            COMMAND ${CMAKE_COMMAND}
                "-DCMAKE_CURRENT_INCLUDE_DIR=${CMAKE_CURRENT_INCLUDE_DIR}"
                "-DFILE_KEY=${ARG_FILE_KEY}"
                "-DFILE_MIME=${ARG_MIME}"
                "-DEMBED_FILE_PATH=${_embed_c}"
                -P "${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/GenerateWasmEmbed.cmake"
            COMMENT "Embedding ${ARG_FILE_KEY} via --embed-file"
            DEPENDS "${ARG_FILE_PATH}" "${CMAKE_CURRENT_INCLUDE_DIR}/xxd_wasm.c.in"
            VERBATIM)
        set_source_files_properties("${_embed_c}" PROPERTIES
            GENERATED TRUE
            COMPILE_FLAGS "-O0")

        # Accumulate --embed-file flags per target; applied at link time by the finalizer.
        foreach(_t IN LISTS ARG_TARGETS)
            set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                APPEND PROPERTY "_XXD_EMBED_FILES_${_t}"
                "${ARG_FILE_PATH}@/xxd/${ARG_FILE_KEY}")
        endforeach()

    elseif(NOT _use_asm)
        # Hex array path: compatible with MSVC and any C compiler.
        set(_hex_file "${XXD_EMBED_BINARY_DIR}/Generated/${ARG_FILE_KEY}.hex")

        # Prefer the xxd executable when available - faster for large files.
        if(TARGET xxd)
            set(_hex_cmd "$<TARGET_FILE:xxd>" -I "${ARG_FILE_PATH}" "${_hex_file}")
            set(_hex_deps xxd "${ARG_FILE_PATH}")
        else()
            set(_hex_cmd ${CMAKE_COMMAND}
                "-DINPUT_FILE=${ARG_FILE_PATH}"
                "-DOUTPUT_FILE=${_hex_file}"
                -P "${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/GenerateHex.cmake")
            set(_hex_deps "${ARG_FILE_PATH}")
        endif()

        add_custom_command(
            OUTPUT "${_hex_file}"
            COMMAND ${_hex_cmd}
            COMMENT "Generating hex for ${ARG_FILE_KEY}"
            DEPENDS ${_hex_deps}
            VERBATIM)
        set_source_files_properties("${_hex_file}" PROPERTIES GENERATED TRUE)

        add_custom_command(
            OUTPUT "${_embed_c}"
            COMMAND ${CMAKE_COMMAND}
                "-DCMAKE_CURRENT_INCLUDE_DIR=${CMAKE_CURRENT_INCLUDE_DIR}"
                "-DFILE_HEX=${_hex_file}"
                "-DFILE_KEY=${ARG_FILE_KEY}"
                "-DFILE_MIME=${ARG_MIME}"
                "-DEMBED_FILE_PATH=${_embed_c}"
                -P "${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/EmbedFile.cmake"
            COMMENT "Embedding ${ARG_FILE_KEY}"
            DEPENDS "${_hex_file}" "${CMAKE_CURRENT_INCLUDE_DIR}/xxd.c.in"
            VERBATIM)

        # Skip optimization on the large generated hex array to speed up compilation.
        if(MSVC)
            set(_embed_optflag "/Od")
        else()
            set(_embed_optflag "-O0")
        endif()
        set_source_files_properties("${_embed_c}" PROPERTIES
            GENERATED TRUE
            COMPILE_FLAGS "${_embed_optflag}")

    else()
        # Inline __asm__ .incbin path: GCC/Clang only, no hex generation step.
        add_custom_command(
            OUTPUT "${_embed_c}"
            COMMAND ${CMAKE_COMMAND}
                "-DCMAKE_CURRENT_INCLUDE_DIR=${CMAKE_CURRENT_INCLUDE_DIR}"
                "-DFILE_KEY=${ARG_FILE_KEY}"
                "-DFILE_PATH=${ARG_FILE_PATH}"
                "-DFILE_MIME=${ARG_MIME}"
                "-DEMBED_FILE_PATH=${_embed_c}"
                -P "${CMAKE_CURRENT_INCLUDE_DIR}/../cmake/GenerateEmbed.cmake"
            COMMENT "Embedding ${ARG_FILE_KEY} via .incbin"
            DEPENDS "${ARG_FILE_PATH}" "${CMAKE_CURRENT_INCLUDE_DIR}/xxd_gas.c.in"
            VERBATIM)

        set_source_files_properties("${_embed_c}" PROPERTIES
            GENERATED TRUE
            COMPILE_FLAGS "-O0")
    endif()

    # Accumulate sources and targets per-directory for deferred lib creation.
    set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        APPEND PROPERTY _XXD_PENDING_SOURCES "${_embed_c}")
    foreach(_t IN LISTS ARG_TARGETS)
        set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            APPEND PROPERTY _XXD_PENDING_TARGETS "${_t}")
    endforeach()

    # Register the deferred finalizer once per directory.
    get_property(_registered DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        PROPERTY _XXD_DEFERRED_REGISTERED)
    if(NOT _registered)
        set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            PROPERTY _XXD_DEFERRED_REGISTERED TRUE)
        cmake_language(DEFER DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            CALL _xxd_create_resource_lib)
    endif()

    message(STATUS "xxd_embed: queued '${ARG_FILE_KEY}' (${ARG_MIME})")
endfunction()

# Build example subdirectory
if(${XXD_BUILD_EXAMPLE})
    add_subdirectory(example)
endif()
