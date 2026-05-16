#include "xxd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct xxd_entry {
  const char* name;
  const char* content;
  size_t size;
  const char* mime;
  struct xxd_entry* next;
} xxd_entry;

/* Head of the singly-linked list of registered resources. */
static xxd_entry* xxd_index = NULL;

void XXD_CALL xxd_add(const char* name, const char* content, size_t size, const char* mime)
{
  xxd_entry* entry = (xxd_entry*)malloc(sizeof(xxd_entry));
  entry->name = name;
  entry->content = content;
  entry->size = size;
  entry->mime = mime;
  entry->next = xxd_index;
  xxd_index = entry;
}

const char* XXD_CALL xxd_get(const char* name, size_t* size, const char** mime)
{
  if (!xxd_index) {
    fprintf(stderr,
      "The resources index maintained by XXD is not [yet] initialized\n"
      "Perhaps, the resource load is attempted before any files have been registered\n"
      "Please make sure this is not the case\n");
    return NULL;
  }

  for (xxd_entry* e = xxd_index; e; e = e->next) {
    if (strcmp(e->name, name) == 0) {
      if (size) *size = e->size;
      if (mime) *mime = e->mime;
      return e->content;
    }
  }
  return NULL;
}
