#ifndef XXD_H
#define XXD_H

#ifdef _WIN32
#  ifdef libxxd_EXPORTS
#    define XXD_EMBED_API __declspec(dllexport)
#  else
#    define XXD_EMBED_API __declspec(dllimport)
#  endif
#else
#  define XXD_EMBED_API
#endif

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Add an entry to the index of embedded resources (internal). */
XXD_EMBED_API void xxd_add(const char* name, const char* content, size_t size, const char* mime);

/* Get an entry from the index of embedded resources. */
XXD_EMBED_API const char* xxd_get(const char* name, size_t* size, const char** mime);

#ifdef __cplusplus
}
#endif

#endif /* XXD_H */
