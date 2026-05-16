#include "xxd.h"

#include <stdio.h>

int main(int argc, char* argv[])
{
  printf("%s", xxd_get("text", NULL, NULL));
  printf("%s", xxd_get("rect", NULL, NULL));
  return 0;
}
