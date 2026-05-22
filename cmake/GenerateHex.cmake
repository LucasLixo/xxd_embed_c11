# CMake 3.20+ script to convert binary file to hex format (equivalent to xxd -i)
# Generates formatted output with 12 bytes per line, matching xxd original formatting
# Usage: cmake -DINPUT_FILE=file.txt -DOUTPUT_FILE=file.hex -P GenerateHex.cmake

if(NOT DEFINED INPUT_FILE OR NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "GenerateHex.cmake requires INPUT_FILE and OUTPUT_FILE variables")
endif()

# Read file in HEX format (CMake 3.20+ feature)
file(READ "${INPUT_FILE}" HEX_CONTENT HEX)

# Format hex string with 12 bytes per line and proper indentation
# Input: "48656c6c6f..." -> Output lines of 12 bytes with formatting
set(FORMATTED_HEX "")
set(BYTE_COUNT 0)

# Process hex string 2 characters at a time (1 byte = 2 hex chars)
string(LENGTH "${HEX_CONTENT}" HEX_LEN)
set(OFFSET 0)

while(OFFSET LESS HEX_LEN)
    # Get next 2 characters (1 byte in hex)
    string(SUBSTRING "${HEX_CONTENT}" ${OFFSET} 2 HEX_BYTE)

    # Add newline and indentation at start of each line
    if(BYTE_COUNT EQUAL 0)
        string(APPEND FORMATTED_HEX "  ")
    endif()

    # Append formatted byte
    string(APPEND FORMATTED_HEX "0x${HEX_BYTE}")

    # Increment byte counter
    math(EXPR BYTE_COUNT "${BYTE_COUNT} + 1")

    # Add comma and newline after 12 bytes or at end
    math(EXPR NEXT_OFFSET "${OFFSET} + 2")
    if(NEXT_OFFSET LESS HEX_LEN)
        if(BYTE_COUNT EQUAL 12)
            string(APPEND FORMATTED_HEX ",\n")
            set(BYTE_COUNT 0)
        else()
            string(APPEND FORMATTED_HEX ", ")
        endif()
    endif()

    math(EXPR OFFSET "${NEXT_OFFSET}")
endwhile()

# Write to output file
file(WRITE "${OUTPUT_FILE}" "${FORMATTED_HEX}")

