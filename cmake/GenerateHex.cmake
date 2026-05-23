# CMake 3.20+ script to convert binary file to hex format (equivalent to xxd -i)
# Single-pass regex conversion — O(n) for arbitrary file sizes.
# Usage: cmake -DINPUT_FILE=file.txt -DOUTPUT_FILE=file.hex -P GenerateHex.cmake

if(NOT DEFINED INPUT_FILE OR NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "GenerateHex.cmake requires INPUT_FILE and OUTPUT_FILE variables")
endif()

# Read file in HEX format (CMake 3.20+ feature)
file(READ "${INPUT_FILE}" HEX_CONTENT HEX)

if(HEX_CONTENT STREQUAL "")
    # Empty input: emit a literal "0" so the template "{ @CONTENT_HEX@, 0 }"
    # expands to the valid C initializer "{ 0, 0 }".
    file(WRITE "${OUTPUT_FILE}" "0")
    return()
endif()

# Convert every hex pair to "0xab, " in a single regex pass.
string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1, " FORMATTED_HEX "${HEX_CONTENT}")

# Drop the trailing ", " so the template terminator "0" follows cleanly.
string(REGEX REPLACE ", $" "" FORMATTED_HEX "${FORMATTED_HEX}")

set(FORMATTED_HEX "  ${FORMATTED_HEX}")

file(WRITE "${OUTPUT_FILE}" "${FORMATTED_HEX}")
