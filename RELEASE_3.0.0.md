# xxd_embed_c11 v3.0.0

## WebAssembly (Emscripten) Support

This release adds first-class WebAssembly support. Resources embedded via `xxd_embed()` are now bundled into the WASM output using Emscripten's native `--embed-file` mechanism — no C arrays, no inline assembly. The existing C API (`xxd_get` / `xxd_add`) is completely unchanged; callers need only switch to the Emscripten toolchain.

---

## What's New

### Emscripten embedding strategy

When `emcmake cmake` is used, `xxd_embed()` automatically activates the WASM path:

1. Each resource file is passed to `emcc` as `--embed-file path@/xxd/<key>`, bundling the raw bytes into the JS/WASM output via Emscripten's virtual file system.
2. A generated C constructor opens `/xxd/<key>` at program startup via `fopen`, reads the bytes, and calls `xxd_add()`.
3. `xxd_get()` and `xxd_add()` are annotated with `EMSCRIPTEN_KEEPALIVE` so they survive dead-code elimination and are accessible from JavaScript.

No CMake options need to change — detection is fully automatic.

### JavaScript interop

Because `xxd_get` is exported via `EMSCRIPTEN_KEEPALIVE`, it can be called directly from JavaScript once the WASM module is ready:

```js
Module.onRuntimeInitialized = function () {
    const ptr  = Module.ccall('xxd_get', 'number', ['string', 'number', 'number'], ['text', 0, 0]);
    const text = Module.UTF8ToString(ptr);
    console.log(text); // Hello, world!
};
```

---

## Breaking Changes

None. The C API, CMake function signature, and behavior on all existing platforms (Linux, Windows, macOS, Android) are unchanged.

---

## Quick Start

```bash
# Install emsdk (once)
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install latest && ./emsdk activate latest
source ./emsdk_env.sh   # or emsdk_env.ps1 on Windows

# Configure and build
emcmake cmake -S . -B build_wasm -DXXD_BUILD_EXAMPLE=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build_wasm

# Run with Node.js
node build_wasm/example/xxd_example.js
```

Expected output:
```
text.txt
    Mime: text/plain
    Size: 13
    Content: Hello, world!
rect.svg
    Mime: image/svg+xml
    Size: 145
    Content: <svg ...>
```

---

## Files Changed

| File | Change |
|------|--------|
| `include/xxd_wasm.c.in` | **New** — constructor template that reads from Emscripten virtual FS |
| `cmake/GenerateWasmEmbed.cmake` | **New** — script that fills in `xxd_wasm.c.in` at build time |
| `CMakeLists.txt` | WASM path in `xxd_embed()`, `--embed-file` in finalizer, skip `xxd` exe for Emscripten, AUTO/ON guards |
| `include/xxd.h` | `__EMSCRIPTEN__` guard with `EMSCRIPTEN_KEEPALIVE` |
| `include/xxd_gas.c.in` | `#error` guard before ELF fallback |

---

## Platform Support Matrix

| Platform | Strategy | Notes |
|----------|----------|-------|
| Linux / BSD | `.incbin` (AUTO) | GCC / Clang, ELF `.rodata` |
| macOS | `.incbin` (AUTO) | Clang, Mach-O `__TEXT,__const` |
| Windows (MSVC) | hex array | `.CRT$XCU` constructor |
| Windows (MinGW / Clang) | `.incbin` (AUTO) | COFF `.rdata` |
| Android NDK | `.incbin` (AUTO) | All ABIs |
| **WebAssembly (Emscripten)** | **`--embed-file` + virtual FS** | **New in v3.0.0** |

---

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md#3.0.0---2026-06-08) for the complete list of changes.
