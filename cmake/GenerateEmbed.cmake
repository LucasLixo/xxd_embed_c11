# Generates a GCC/Clang C source file with inline __asm__ .incbin for binary embedding.
# Required inputs (passed via -D): FILE_KEY, FILE_PATH, FILE_MIME,
# EMBED_FILE_PATH, CMAKE_CURRENT_INCLUDE_DIR
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

string(SHA256 FILE_KEY_HASH "${FILE_KEY}")

# Normalize to forward slashes and escape any double-quotes for use in C string literals.
file(TO_CMAKE_PATH "${FILE_PATH}" FILE_PATH_ESCAPED)
string(REPLACE "\"" "\\\"" FILE_PATH_ESCAPED "${FILE_PATH_ESCAPED}")

file(READ "${CMAKE_CURRENT_INCLUDE_DIR}/xxd_gas.c.in" _content)
string(REPLACE "@FILE_KEY_HASH@"     "${FILE_KEY_HASH}"     _content "${_content}")
string(REPLACE "@FILE_KEY@"          "${FILE_KEY}"          _content "${_content}")
string(REPLACE "@FILE_MIME@"         "${FILE_MIME}"         _content "${_content}")
string(REPLACE "@FILE_PATH_ESCAPED@" "${FILE_PATH_ESCAPED}" _content "${_content}")

# Always write (not configure_file) to update the timestamp even when content is unchanged,
# ensuring the compiler re-assembles .incbin when the embedded file changes.
file(WRITE "${EMBED_FILE_PATH}" "${_content}")
