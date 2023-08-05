void putch(char c) {
  char *uart0 = (char *)0x10000000;
  *uart0 = c;
}

void putstr(char *str) {
  while(*str != 0) {
    putch(*str);
    str++;
  }
}

int fibonacchi(int max) {
  if (max == 0) {
    return 0;
  } else if (max == 1 || max == 2) {
    return 1;
  } else {
    return fibonacchi(max - 1) + fibonacchi(max - 2);
  }
}
int main(void) {
  // int a = myfunc(1);
  int a = fibonacchi(7);
  // for (int i = 0; i < 100000; i++) {
  // }
  putstr("Hello from C!\n");
  return a;
}
