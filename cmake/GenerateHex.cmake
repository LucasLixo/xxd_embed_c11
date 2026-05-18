# CMake 3.20+ script to convert binary file to hex format (equivalent to xxd -i)
# Usage: cmake -DINPUT_FILE=file.txt -DOUTPUT_FILE=file.hex -P GenerateHex.cmake

if(NOT DEFINED INPUT_FILE OR NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "GenerateHex.cmake requires INPUT_FILE and OUTPUT_FILE variables")
endif()

# Read file in HEX format (CMake 3.20+ feature)
file(READ "${INPUT_FILE}" HEX_CONTENT HEX)

# Convert continuous hex string to comma-separated byte array format
# Input: "48656c6c6f" -> Output: "0x48, 0x65, 0x6c, 0x6c, 0x6f"
string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1, " FORMATTED_HEX "${HEX_CONTENT}")

# Remove trailing comma and space
string(REGEX REPLACE ", $" "" FORMATTED_HEX "${FORMATTED_HEX}")

# Write to output file
file(WRITE "${OUTPUT_FILE}" "${FORMATTED_HEX}")

