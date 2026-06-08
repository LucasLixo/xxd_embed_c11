# Generates a C source file for Emscripten that reads from the virtual FS at startup.
# Required inputs (passed via -D): FILE_KEY, FILE_MIME,
# EMBED_FILE_PATH, CMAKE_CURRENT_INCLUDE_DIR
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

string(SHA256 FILE_KEY_HASH "${FILE_KEY}")

file(READ "${CMAKE_CURRENT_INCLUDE_DIR}/xxd_wasm.c.in" _content)
string(REPLACE "@FILE_KEY_HASH@" "${FILE_KEY_HASH}" _content "${_content}")
string(REPLACE "@FILE_KEY@"      "${FILE_KEY}"      _content "${_content}")
string(REPLACE "@FILE_MIME@"     "${FILE_MIME}"     _content "${_content}")

file(WRITE "${EMBED_FILE_PATH}" "${_content}")
