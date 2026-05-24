#include "xxd.h"

#include <stddef.h>
#include <stdio.h>
#include <stdint.h>

int32_t main(int32_t argc, char* argv[])
{
  size_t textSize = 0ULL;
  const char* textMime = NULL;
  const char* textContent = xxd_get("text", &textSize, &textMime);

  size_t rectSize = 0ULL;
  const char* rectMime = NULL;
  const char* rectContent = xxd_get("rect", &rectSize, &rectMime);

  printf("text.txt\n\tMime: %s\n\tSize: %zu\n\tContent: %s\n", textMime, textSize, textContent);
  printf("rect.svg\n\tMime: %s\n\tSize: %zu\n\tContent: %s\n", rectMime, rectSize, rectContent);
  return (int32_t)0;
}
