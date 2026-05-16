# Embed resources into binary with XXD and CMake

Embed resources into binary with XXD and CMake in a cross-platform way (Linux, Windows and Mac support).

XXD converts the data file into a C array, which is slow to compile for large files, due to the way how compiler handles large static arrays. In order to embed large files, please use [res_embed](https://github.com/dmikushin/res_embed.git) instead.

## Example

1. Add this project to your CMake project as a submodule:

```
git submodule add https://github.com/LucasLixo/xxd_embed_c11.git some/path/xxd
```

2. Integrate into your `CMakeLists.txt`:

```cmake
add_subdirectory(some/path/xxd)
```

3. Embed resource files using the `xxd_embed` macro:

```cmake
set(SRCS "main.c")
xxd_embed("text" "${CMAKE_CURRENT_SOURCE_DIR}/text.txt" SRCS)
xxd_embed("rect" "${CMAKE_CURRENT_SOURCE_DIR}/rect.svg" SRCS)

add_executable(xxd_example ${SRCS})
target_link_libraries(xxd_example xxd::xxd)
```

4. Access the embedded resources in your C code:

```c
#include "xxd.h"
#include <stdio.h>

int main(int argc, char* argv[])
{
    printf("%s", xxd_get("text", NULL, NULL));
    printf("%s", xxd_get("rect", NULL, NULL));
    return 0;
}
```

## CMake options

| Option | Default | Description |
|--------|---------|-------------|
| `XXD_BUILD_STATIC` | `ON` | Build `libxxd` as a static library. Set to `OFF` to build as a shared library (`.dll`/`.so`). |
| `XXD_BUILD_EXAMPLE` | `ON` | Build the bundled example executable. |

Configure from the command line:

```
cmake -B build -DXXD_BUILD_STATIC=ON -DXXD_BUILD_EXAMPLE=OFF
```

## CMake macro

```cmake
xxd_embed(<key> <file_path> <sources_list>)
```

| Parameter | Description |
|-----------|-------------|
| `key` | Name used to retrieve the resource at runtime via `xxd_get`. |
| `file_path` | Absolute path to the file to embed. |
| `sources_list` | CMake list variable to append the generated `.c` file to. |

## Preprocessor macros

These macros control the visibility of the public API symbols when including `xxd.h`.

| Macro | When to define | Effect |
|-------|---------------|--------|
| `XXD_STATIC` | When linking against the static library | Disables `__declspec(dllimport/dllexport)` on Windows. Automatically defined by CMake when `XXD_BUILD_STATIC=ON`. |
| `XXD_EXPORTS` | When building `libxxd` itself as a shared library | Marks API symbols as `__declspec(dllexport)`. Defined automatically by the build system; not needed by consumers. |

When using CMake and `target_link_libraries(my_app xxd::xxd)`, these macros are set automatically — no manual definition is required.

## API

```c
/* Register an embedded resource (called automatically by generated code). */
void xxd_add(const char* name, const char* content, size_t size, const char* mime);

/* Retrieve an embedded resource by name.
   Returns a pointer to the raw bytes, or NULL if not found.
   Optionally writes the byte count to *size and the MIME type string to *mime. */
const char* xxd_get(const char* name, size_t* size, const char** mime);
```

`xxd_add` is called automatically at program startup for every file embedded via `xxd_embed` — user code only needs to call `xxd_get`.

## License

Shield: [![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)

This is free and unencumbered software released into the public domain.

For more information, please refer to [http://unlicense.org/](http://unlicense.org/)

## Credits

This code uses the original public domain `xxd` utility, which is

(c) 1990-1998 by Juergen Weigert
