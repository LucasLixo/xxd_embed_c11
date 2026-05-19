#include "xxd.h"

#include <stdio.h>
#include <stdint.h>

int32_t main(int32_t argc, char* argv[])
{
  printf("text.txt\n%s\n", xxd_get("text", NULL, NULL));
  printf("rect.svg\n%s\n", xxd_get("rect", NULL, NULL));
  return (int32_t)0;
}
