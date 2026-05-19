# Changelog {#changelog}

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - 2026-05-19

- Support for fixed-width integer types from `stdint.h` throughout the codebase
- Explicit `#include <stdint.h>` in all source files for type safety and portability

### Changed - 2026-05-19

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

[Unreleased]: https://github.com/LucasLixo/xxd_embed_c11/compare/1.1.0...HEAD
[1.1.0]: https://github.com/LucasLixo/xxd_embed_c11/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/LucasLixo/xxd_embed_c11/releases/tag/1.0.0
