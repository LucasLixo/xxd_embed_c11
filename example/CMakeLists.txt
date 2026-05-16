# Initialize source file list
set(SRCS "example.cpp")

# Embed resource file into C++ source
xxd_embed("resource" "${CMAKE_CURRENT_SOURCE_DIR}/resource" SRCS)

# Build example executable
add_executable(xxd_example ${SRCS})

# Link against xxd library
target_link_libraries(xxd_example xxd::xxd)
