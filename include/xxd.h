#ifndef XXD_H
#define XXD_H

#ifdef __EMSCRIPTEN__
#  include <emscripten.h>
#  define XXD_CALL
#  define XXD_EMBED_API EMSCRIPTEN_KEEPALIVE
#elif defined(_WIN32)
#  define XXD_CALL __cdecl
#  ifdef XXD_STATIC
#    define XXD_EMBED_API
#  elif defined(XXD_EXPORTS)
#    define XXD_EMBED_API __declspec(dllexport)
#  else
#    define XXD_EMBED_API __declspec(dllimport)
#  endif
#else
#  define XXD_CALL
#  if defined(__GNUC__) && defined(XXD_EXPORTS)
#    define XXD_EMBED_API __attribute__((visibility("default")))
#  else
#    define XXD_EMBED_API
#  endif
#endif

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Add an entry to the index of embedded resources (internal). */
XXD_EMBED_API void XXD_CALL xxd_add(const char* name, const char* content, size_t size, const char* mime);

/* Get an entry from the index of embedded resources. */
XXD_EMBED_API const char* XXD_CALL xxd_get(const char* name, size_t* size, const char** mime);

#ifdef __cplusplus
}
#endif

#endif /* XXD_H */
