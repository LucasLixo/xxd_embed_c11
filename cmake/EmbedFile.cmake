# Set minimum CMake version
cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

# Read hex content from generated file
file(READ ${FILE_HEX} CONTENT_HEX)

# Generate SHA256 hash of file key for unique identifiers
string(SHA256 FILE_KEY_HASH ${FILE_KEY})

# Detect MIME type of the file (optional)
find_program(XDG_MIME xdg-mime)
if (XDG_MIME)
    # Query MIME type using xdg-mime command
    execute_process(COMMAND ${XDG_MIME} query filetype ${FILE_PATH} OUTPUT_VARIABLE FILE_MIME)
    # Strip trailing whitespace (newline) from output
    string(STRIP "${FILE_MIME}" FILE_MIME)
else()
    set(FILE_MIME "unsupported")
endif()

# Generate C source file from template, substituting hex content
configure_file("${CMAKE_CURRENT_INCLUDE_DIR}/xxd.in" ${EMBED_FILE_PATH})
