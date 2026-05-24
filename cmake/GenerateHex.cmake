# CMake 3.20+ script to convert binary to hex format compatible with xxd -I output.
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT DEFINED INPUT_FILE OR NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "GenerateHex.cmake requires INPUT_FILE and OUTPUT_FILE variables")
endif()

file(READ "${INPUT_FILE}" HEX_CONTENT HEX)

if(HEX_CONTENT STREQUAL "")
    file(WRITE "${OUTPUT_FILE}" "0")
    return()
endif()

string(REGEX MATCHALL "[0-9a-f][0-9a-f]" HEX_LIST "${HEX_CONTENT}")

set(_result "")
set(_col 0)
set(_line "")

foreach(_byte IN LISTS HEX_LIST)
    if(_col EQUAL 0)
        string(APPEND _line "  0x${_byte}")
    else()
        string(APPEND _line ", 0x${_byte}")
    endif()
    math(EXPR _col "${_col} + 1")
    if(_col EQUAL 12)
        string(APPEND _result "${_line},\n")
        set(_line "")
        set(_col 0)
    endif()
endforeach()

if(_line)
    string(APPEND _result "${_line}")
endif()

# Trailing newline to match xxd -I output exactly.
string(APPEND _result "\n")

file(WRITE "${OUTPUT_FILE}" "${_result}")
