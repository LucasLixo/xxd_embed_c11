# Embed resources into binary with XXD and CMake

[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)
[![CMake](https://img.shields.io/badge/CMake-3.24%2B-blue.svg)](https://cmake.org)
[![C Standard](https://img.shields.io/badge/C-C11-blue.svg)](https://en.wikipedia.org/wiki/C11_(C_standard_revision))

Embed resources into binary with CMake in a cross-platform way (Linux, Windows, macOS and [Android](#platform-notes) support).

**Requires CMake 3.24 or higher.**

## Release Notes

### Version 2.0.0 (Current)

**Major changes (breaking):**
- **New `xxd_embed()` function** — replaces the old positional macro with named arguments (`FILE_KEY`, `FILE_PATH`, `MIME`, `TARGETS`). `MIME` is now required and supplied by the caller.
- **Automatic per-directory resource library** — generated translation units are bundled into a deferred static library (`xxd_resources_<hash>`) and linked into the listed `TARGETS` via `WHOLE_ARCHIVE`. No more `set(SRCS ...)` plumbing in the caller.
- **Assembly-based embedding (`.incbin`)** — on GCC/Clang, files are embedded via inline `__asm__(".incbin ...")` instead of generated hex arrays. Compile time drops by orders of magnitude for large files because the assembler streams the bytes verbatim.
- **`xxd -I` flag** — new `-I` flag emits raw hex bytes (12 per line) without the surrounding C array declaration; the output is bit-identical to `cmake/GenerateHex.cmake`. When the `xxd` target is available, the hex path uses the executable for speed.
- **`XXD_EMBED_ASM` option** — choose the embedding strategy: `AUTO` (compiler-detected, default), `ON` (force `.incbin`), `OFF` (force hex array).
- **Removed `xdg-mime` auto-detection** — MIME type was unreliable across platforms; now the caller passes it explicitly.

**Minimum CMake bumped: 3.20 → 3.24** (required for `$<LINK_LIBRARY:WHOLE_ARCHIVE,...>`).

### Version 1.1.0

Removed the external `xxd` dependency by switching hex conversion to native CMake `file(READ ... HEX)`. CMake 3.20+ required.

### Version 1.0.0

Original release with `xxd` executable dependency for hex conversion.

## Example

1. Add this project to your CMake project as a submodule:

```
git submodule add https://github.com/LucasLixo/xxd_embed_c11.git some/path/xxd
```

2. Integrate into your `CMakeLists.txt`:

```cmake
add_subdirectory(some/path/xxd)
```

3. Embed resource files using the `xxd_embed` function:

```cmake
add_executable(xxd_example main.c)

xxd_embed(
    FILE_KEY  "text"
    FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/text.txt"
    MIME      "text/plain"
    TARGETS   xxd_example
)
xxd_embed(
    FILE_KEY  "rect"
    FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/rect.svg"
    MIME      "image/svg+xml"
    TARGETS   xxd_example
)
# A per-directory static lib xxd_resources_<hash> is created at the end of
# configuration and linked into every listed target. xxd::xxd is propagated
# transitively, so no manual target_link_libraries call is needed.
```

4. Access the embedded resources in your C code:

```c
#include "xxd.h"
#include <stdio.h>

int main(int argc, char* argv[])
{
    printf("text.txt\n%s\n", xxd_get("text", NULL, NULL));
    printf("rect.svg\n%s\n", xxd_get("rect", NULL, NULL));
    return 0;
}
```

## CMake options

| Option | Default | Description |
|--------|---------|-------------|
| `XXD_BUILD_EXECUTABLE` | `ON` | Build the `xxd` standalone executable. Set to `OFF` to disable (resource embedding still works). |
| `XXD_BUILD_STATIC` | `ON` | Build `libxxd` as a static library. Set to `OFF` to build as a shared library (`.dll`/`.so`). |
| `XXD_BUILD_EXAMPLE` | `ON` | Build the bundled example executable. |
| `XXD_EMBED_ASM` | `AUTO` | Embedding strategy: `AUTO` (MSVC → hex array, GCC/Clang → `.incbin`), `ON` (force `.incbin`), `OFF` (force hex array). |

Configure from the command line:

```
cmake -S . -B build -DXXD_BUILD_STATIC=ON -DXXD_BUILD_EXAMPLE=OFF
cmake --build build
```

Force the slower-but-portable hex path on a GCC/Clang toolchain:

```
cmake -S . -B build -DXXD_EMBED_ASM=OFF
```

### CMake Policy CMP0118

This project requires CMake policy CMP0118 to be set to `NEW`. This policy is necessary so that generated assets (e.g., xxd_embed outputs) attached via `INTERFACE` sources on a target in one directory are accepted by consumer targets defined in other directories.

Add the following to your `CMakeLists.txt` before including this project:

```cmake
# Policy CMP0118: GENERATED source-file property is global across directory scopes.
# Required so generated assets (e.g. xxd_embed outputs) attached via INTERFACE sources
# on a target in one directory are accepted by consumer targets defined in other
# directories. CMAKE_POLICY_DEFAULT_CMP0118 survives subdirectory cmake_minimum_required
# resets (which would otherwise unset CMP0118, introduced in CMake 3.20).
set(CMAKE_POLICY_DEFAULT_CMP0118 NEW)
if(POLICY CMP0118)
    cmake_policy(SET CMP0118 NEW)
endif()
```

Note: `CMAKE_POLICY_DEFAULT_CMP0118` survives subdirectory `cmake_minimum_required` resets, which would otherwise unset CMP0118 (introduced in CMake 3.20).

## CMake function

```cmake
xxd_embed(
    FILE_KEY  <key>
    FILE_PATH <absolute_path>
    MIME      <mime_type>
    TARGETS   <target1> [<target2> ...]
)
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `FILE_KEY` | yes | Name used to retrieve the resource at runtime via `xxd_get`. |
| `FILE_PATH` | yes | Absolute path to the file to embed. |
| `MIME` | yes | MIME type string returned by `xxd_get` via its `mime` out-parameter. |
| `TARGETS` | yes | One or more targets that will receive the embedded resource at link time. |

Calls are accumulated per source directory; at the end of configuration a single `xxd_resources_<hash>` static library is created from all embed sources and linked into every listed target (using `WHOLE_ARCHIVE` so global constructors are not dropped).

### Choosing the embedding strategy

`AUTO` (default) selects `.incbin` for GCC/Clang and the hex-array path for MSVC. The `.incbin` path is dramatically faster to compile for large files because the assembler copies the bytes directly instead of parsing thousands of hex literals.

Override with `XXD_EMBED_ASM=ON` or `OFF` when cross-compiling or when the auto-detection does not match the toolchain.

## Preprocessor macros

These macros control the visibility of the public API symbols when including `xxd.h`.

| Macro | When to define | Effect |
|-------|---------------|--------|
| `XXD_STATIC` | When linking against the static library | Disables `__declspec(dllimport/dllexport)` on Windows. Automatically defined by CMake when `XXD_BUILD_STATIC=ON`. |
| `XXD_EXPORTS` | When building `libxxd` itself as a shared library | Marks API symbols as `__declspec(dllexport)`. Defined automatically by the build system; not needed by consumers. |

When using CMake and `xxd_embed(... TARGETS my_app)`, these macros are set automatically — no manual definition is required.

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

## `xxd` command-line flags

In addition to the standard `xxd` flags, this build adds:

| Flag | Description |
|------|-------------|
| `-I` | Embed-only: emit hex bytes (12 per line) without the surrounding C array declaration. Output is bit-identical to `cmake/GenerateHex.cmake`. |

## Platform notes

### Android (NDK cross-compilation)

Resource embedding works automatically on all platforms including Android. On the NDK (GCC/Clang) the `.incbin` path is used by default.

#### Step 1 — Install the NDK

In Android Studio open `File → Settings → Languages & Frameworks → Android SDK → SDK Tools`, tick **NDK (Side by side)** and apply. Note the version number shown (e.g. `30.0.14904198`). The NDK is installed at:

```
# Windows
%LOCALAPPDATA%\Android\Sdk\ndk\<version>\

# Linux / macOS
$HOME/Android/Sdk/ndk/<version>/
```

#### Step 2 — Configure for Android

**Linux / macOS:**
```bash
cmake -B build_android -S . \
    -DCMAKE_TOOLCHAIN_FILE=$HOME/Android/Sdk/ndk/<version>/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-21 \
    -DXXD_BUILD_STATIC=ON \
    -DXXD_BUILD_EXAMPLE=OFF
```

**Windows (PowerShell):**
```powershell
cmake -B build_android -S . `
    -DCMAKE_TOOLCHAIN_FILE="$env:LOCALAPPDATA\Android\Sdk\ndk\<version>\build\cmake\android.toolchain.cmake" `
    -DANDROID_ABI=arm64-v8a `
    -DANDROID_PLATFORM=android-21 `
    -DXXD_BUILD_STATIC=ON `
    -DXXD_BUILD_EXAMPLE=OFF
```

#### Step 3 — Build

```
cmake --build build_android
```

The output is `build_android/libxxd.a` (or `build_android\libxxd.a` on Windows).

#### Step 4 — Verify (optional)

Confirm the library targets AArch64:

```powershell
# Windows — using the NDK's llvm-readelf
& "$env:LOCALAPPDATA\Android\Sdk\ndk\<version>\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe" `
  --file-headers build_android\libxxd.a
```

```bash
# Linux / macOS
llvm-readelf --file-headers build_android/libxxd.a
```

Expected output includes `Machine: AArch64` and `Type: REL (Relocatable file)`.

#### Supported ABIs

| ABI | Description |
|-----|-------------|
| `arm64-v8a` | 64-bit ARM — modern devices (recommended) |
| `armeabi-v7a` | 32-bit ARM — older devices |
| `x86` | 32-bit x86 — emulator |
| `x86_64` | 64-bit x86 — emulator |

`XXD_BUILD_STATIC=ON` is the default and required for Android — it produces `libxxd.a` that links cleanly into your APK via the NDK.

## License

Shield: [![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)

This is free and unencumbered software released into the public domain.

For more information, please refer to [http://unlicense.org/](http://unlicense.org/)

## Credits

This code uses the original public domain `xxd` utility, which is

(c) 1990-1998 by Juergen Weigert
