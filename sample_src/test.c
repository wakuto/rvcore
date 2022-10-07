int fibonacchi(int max) {
  if (max == 1)
    return 1;
  else if (max == 2)
    return 1;
  else
    return fibonacchi(max - 1) + fibonacchi(max - 2);
}
int main(void) {
  int a = fibonacchi(1);
  return a;
}
