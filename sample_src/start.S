.section .text.init
.global _start
_start:

  addi x5, x0, 10
.loop:
  addi x5, x5, -1
  bne  x5, x0, .loop
  jal  x1, my_func
  ebreak

my_func:
  addi x4, x0, 0xaf
  jalr x0, x1, 0
#  lui sp, 0x9FFFF
#  j main
