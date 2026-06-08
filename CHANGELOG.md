# Changelog {#changelog}

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-06-08

This release adds first-class WebAssembly support via Emscripten. Resources are embedded using Emscripten's native `--embed-file` mechanism instead of C arrays or assembly, and the public API (`xxd_get` / `xxd_add`) is exported to JavaScript automatically.

### Added

- **WebAssembly (Emscripten) embedding strategy** (`include/xxd_wasm.c.in` + `cmake/GenerateWasmEmbed.cmake`): when the Emscripten toolchain is detected, each resource is passed to `emcc` via `--embed-file path@/xxd/<key>`. A constructor-based C file opens the virtual-FS path at startup (`fopen("/xxd/<key>", "rb")`), reads the bytes into a `malloc` buffer, and calls `xxd_add()`. The existing `xxd_get` API is unchanged.
- **`EMSCRIPTEN_KEEPALIVE` on public API**: `xxd_get` and `xxd_add` are annotated in `xxd.h` so they survive dead-code elimination and are accessible from JavaScript via `Module.ccall` / `Module.cwrap`.
- **`--embed-file` link options applied automatically**: the `_xxd_create_resource_lib()` finalizer accumulates the correct `--embed-file path@/xxd/<key>` flags and applies them to each final target via `target_link_options()`.
- **`#error` guard in `xxd_gas.c.in`**: a compile-time error fires if the `.incbin` template is ever reached under `__EMSCRIPTEN__`, preventing a silent miscompile.

### Changed

- **`XXD_BUILD_EXECUTABLE` skipped for Emscripten**: the `xxd` standalone tool is not built when `EMSCRIPTEN` is set — a WASM binary cannot run on the host as a build tool. Hex generation falls back to `GenerateHex.cmake` automatically.
- **`XXD_EMBED_ASM` AUTO now treats Emscripten like MSVC**: forces the hex-array path (immediately overridden to the WASM strategy internally). `XXD_EMBED_ASM=ON` is rejected with a `FATAL_ERROR` when Emscripten is active.
- **`include/xxd.h` platform guards reordered**: `__EMSCRIPTEN__` is checked before `_WIN32` so the WASM branch takes precedence on all Emscripten toolchains.
- **`libxxd` source list updated** to include `include/xxd_wasm.c.in` and `cmake/GenerateWasmEmbed.cmake` (visible in IDE project trees).
- Project version bumped to `3.0.0`.

## [2.0.0] - 2026-05-23

This release modernizes the CMake API and adds an assembly-based embedding path that drops compile time by orders of magnitude for large files. The old positional `xxd_embed` macro is replaced by a named-argument function; the resulting source files are bundled into a per-directory static library that is linked automatically into the listed targets.

### Added

- **`xxd_embed()` function** with named arguments (`FILE_KEY`, `FILE_PATH`, `MIME`, `TARGETS`). All arguments are required; missing ones produce a `FATAL_ERROR` at configure time.
- **Per-directory resource library**: every `xxd_embed` call in a directory accumulates into a single `xxd_resources_<hash>` static library, created via `cmake_language(DEFER)` and linked into each listed target with `$<LINK_LIBRARY:WHOLE_ARCHIVE,...>` so global constructors are preserved. `xxd::xxd` is propagated transitively — consumers no longer need to call `target_link_libraries` manually.
- **`.incbin` embedding path** (`cmake/GenerateEmbed.cmake` + `include/xxd_gas.c.in`): on GCC/Clang the embedded payload is emitted via inline `__asm__(".incbin ...")` instead of a hex array, so the assembler streams the bytes directly without parsing literals. Targets macOS (`__TEXT,__const`), Windows COFF (`.rdata`), and ELF (`.rodata`).
- **`XXD_EMBED_ASM` cache option** to override embedding strategy: `AUTO` (default — `.incbin` on GCC/Clang, hex array on MSVC), `ON` (force `.incbin`), `OFF` (force hex array).
- **`xxd -I` flag**: embed-only output that emits hex bytes (12 per line) without the surrounding C array declaration. Output is bit-identical to `cmake/GenerateHex.cmake`, so the two are interchangeable; the executable is preferred when available because it is faster on large files.
- New file `cmake/GenerateEmbed.cmake` and template `include/xxd_gas.c.in`.

### Changed

- **Minimum CMake bumped to 3.24** (previously 3.20) — required for `$<LINK_LIBRARY:WHOLE_ARCHIVE,...>`.
- **`cmake/GenerateHex.cmake`** now emits multi-line output (12 bytes per line) matching `xxd -I` exactly, including the trailing newline.
- **`cmake/EmbedFile.cmake`** no longer detects MIME via `xdg-mime`; the value is supplied by the caller via `-DFILE_MIME=...`.
- **`include/xxd.in` renamed to `include/xxd.c.in`** so the `.c.in` suffix matches the new gas template (`include/xxd_gas.c.in`). Content is otherwise unchanged.
- **Optimization flag for the hex path** is now compiler-aware: `/Od` on MSVC, `-O0` elsewhere. Previously hardcoded `/Od` would break a forced hex build on GCC/Clang.
- Project version bumped to `2.0.0`.

### Removed

- The old positional `macro(xxd_embed FILE_KEY FILE_PATH SOURCES)`. Callers must migrate to the new function — see README.md.
- Automatic MIME detection via `xdg-mime` (unreliable across platforms, missing on Windows).

### Migration from 1.x

Before:
```cmake
set(SRCS "main.c")
xxd_embed("text" "${CMAKE_CURRENT_SOURCE_DIR}/text.txt" SRCS)
add_executable(my_app ${SRCS})
target_link_libraries(my_app xxd::xxd)
```

After:
```cmake
add_executable(my_app main.c)
xxd_embed(
    FILE_KEY  "text"
    FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/text.txt"
    MIME      "text/plain"
    TARGETS   my_app
)
```

The static resource library and `xxd::xxd` are linked automatically.

## [1.1.1] - 2026-05-19

### Added

- Support for fixed-width integer types from `stdint.h` throughout the codebase
- Explicit `#include <stdint.h>` in all source files for type safety and portability

### Changed

- **Type System Migration**: Migrated entire codebase to use fixed-width integer types:
  - `int` → `int32_t` for variables and function parameters
  - `long` → `int64_t` for offset and size calculations
  - `unsigned char` → `uint8_t` for binary data
  - `unsigned int` → `uint32_t` for length fields
- Updated function prototypes in `xxd.h`, `xxd.in`, and all source files
- Enhanced portability and consistency across different platform architectures
- All file I/O operations now use explicit type specifications

## [1.1.0] - 2026-05-18

This release eliminates the dependency on the external xxd utility by leveraging native CMake hex conversion (available in CMake 3.20+). This makes the build process simpler, faster, and more portable.

Key Improvements:

- No external dependencies: Removed the requirement for xxd to be installed or cross-compiled as a build tool
- Native CMake support: Uses CMake 3.20+ built-in file(READ HEX) for universal hex conversion
- Optional executable: Introduced XXD_BUILD_EXECUTABLE option (default ON) to optionally disable standalone xxd compilation
- Organized output: Generated .hex and .c files are now placed in a dedicated <binary-dir>/Generated/ subdirectory
- Better formatting: Hex output maintains xxd-compatible formatting (12 bytes per line with proper indentation)
- Simplified cross-compilation: Android NDK builds no longer require external tools or workarounds

Backward Compatibility:

All existing code continues to work without modification. The library API and functionality remain unchanged. Users upgrading from 1.0.0 will only need CMake 3.20+ instead of 3.5+.

Build Option:

- -DXXD_BUILD_EXECUTABLE=ON (default): Builds the standalone xxd executable in addition to the library
- -DXXD_BUILD_EXECUTABLE=OFF: Disables xxd executable build (library and embedding functionality still work)

Technical Details:

The hex conversion is now performed by cmake/GenerateHex.cmake, which reads files in binary mode and formats them identically to the original xxd -i output, ensuring generated code compatibility with existing embedding patterns.

Breaking Change:

CMake minimum version requirement increased from 3.5 to 3.20 (released 2021, widely available).

## xxd Command-Line Tool History (Original)

The following is the historical changelog from the original xxd utility:

- **2.10.90**: Changed to word output
- **3.03.93**: New indent style, dumb bug inserted and fixed. Added `-c` option
- **26.04.94**: Better option parser, added `-ps`, `-l`, `-s` options
- **1.07.94**: Improved `-r` option, per default autoskip over consecutive zero lines. Added `-a` option
- **1.11.95**: Improved `-i` output as C include format. Enhanced `-s` and `-r` options
- **3.04.96**: Autoskip defaults to off. Added `-v` option. Fixed `-a` option. Added `-u` for uppercase hex. Enhanced usage documentation
- **16.05.96**: Improved `-p` option, removed occasional superfluous linefeed
- **20.05.96**: Fixed `-l 0` behavior
- **21.05.96**: Fixed `-i` option, added `__` prefix for numeric filenames. Added Windows NT support (`-DWIN32`)
- **25.05.96**: Added macOS support (CodeWarrior integration)
- **7.06.96**: Fixed `-i` to output 'char' instead of 'int'. Added OS/2 support
- **18.07.96**: Improved GCC compatibility. Added OS version detection
- **29.08.96**: Added `size_t` support for Amiga
- **24.03.97**: Windows NT support (Phil Hanna). Clean exit for Amiga Workbench
- **02.04.97**: Added `-E` option for EBCDIC translation
- **22.05.97**: Added `-g` option for grouping octets
- **23.09.98**: Fixed `-p -r` misfeature
- **26.09.98**: Fixed `-i` output truncation
- **27.10.98**: Fixed `-g` option parser. Added `-b` option for binary output

[3.0.0]: https://github.com/LucasLixo/xxd_embed_c11/compare/2.0.0...3.0.0
[2.0.0]: https://github.com/LucasLixo/xxd_embed_c11/compare/1.1.1...2.0.0
[1.1.1]: https://github.com/LucasLixo/xxd_embed_c11/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/LucasLixo/xxd_embed_c11/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/LucasLixo/xxd_embed_c11/releases/tag/1.0.0
