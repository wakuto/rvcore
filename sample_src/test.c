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
  int a = fibonacchi(10);
  return a;
}
