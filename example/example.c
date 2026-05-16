#include "xxd.h"

#include <stdio.h>

int main(int argc, char* argv[])
{
  printf("text.txt\n%s\n", xxd_get("text", NULL, NULL));
  printf("rect.svg\n%s\n", xxd_get("rect", NULL, NULL));
  return 0;
}
