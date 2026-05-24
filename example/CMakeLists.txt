add_executable(xxd_example example.c)

xxd_embed(
    FILE_KEY "text"
    FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/text.txt"
    MIME "text/plain"
    TARGETS xxd_example
)
xxd_embed(
    FILE_KEY "rect"
    FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/rect.svg"
    MIME "image/svg+xml"
    TARGETS xxd_example
)
# xxd_resources_<hash> static lib and xxd::xxd are linked automatically via cmake_language(DEFER).
