# Initialize source file list
set(SRCS "example.c")

# Embed resource file into C source
xxd_embed("text" "${CMAKE_CURRENT_SOURCE_DIR}/text.txt" SRCS)
xxd_embed("rect" "${CMAKE_CURRENT_SOURCE_DIR}/rect.svg" SRCS)

# Build example executable
add_executable(xxd_example ${SRCS})

# Link against xxd library
target_link_libraries(xxd_example xxd::xxd)
