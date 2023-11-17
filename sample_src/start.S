.section .text.init
.global _start
_start:
  addi x1, x0, 0
  addi x2, x0, 1

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0

  add  x3, x1, x2
  addi x1, x2, 0
  addi x2, x3, 0
