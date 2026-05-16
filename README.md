# Embed resources into binary with XXD and CMake

Embed resources into binary with XXD and CMake in a cross-platform way (Linux, Windows, macOS and [Android](#platform-notes) support).

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
    printf("text.txt\n%s\n", xxd_get("text", NULL, NULL));
    printf("rect.svg\n%s\n", xxd_get("rect", NULL, NULL));
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

## Platform notes

### Android (NDK cross-compilation)

The `xxd` utility must run on the **build host** at configure time to generate the hex files. When cross-compiling with the Android NDK, CMake cannot build a host executable automatically, so `xxd` must be available on the build machine beforehand.

#### Step 1 — Install the NDK

In Android Studio open `File → Settings → Languages & Frameworks → Android SDK → SDK Tools`, tick **NDK (Side by side)** and apply. Note the version number shown (e.g. `30.0.14904198`). The NDK is installed at:

```
# Windows
%LOCALAPPDATA%\Android\Sdk\ndk\<version>\

# Linux / macOS
$HOME/Android/Sdk/ndk/<version>/
```

#### Step 2 — Make xxd available on the host

`xxd` must be accessible in `PATH` on the build machine. Alternatively, pass its path directly via `-DXXD_HOST_EXECUTABLE=...` at configure time (see Step 3).

```bash
# Debian / Ubuntu
sudo apt install xxd

# macOS
brew install vim # xxd ships with vim

# Windows — build the host tool from this project first, then add it to PATH
cmake -B build_host -S . -DXXD_BUILD_EXAMPLE=OFF
cmake --build build_host --target xxd
# build_host\xxd.exe is now available — pass it via -DXXD_HOST_EXECUTABLE below
```

#### Step 3 — Configure for Android

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
    -DXXD_BUILD_EXAMPLE=OFF `
    -DXXD_HOST_EXECUTABLE="build_host\xxd.exe"
```

#### Step 4 — Build

```
cmake --build build_android
```

The output is `build_android/libxxd.a` (or `build_android\libxxd.a` on Windows).

#### Step 5 — Verify (optional)

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
