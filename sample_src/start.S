.section .text.init
.global _start
_start:
  addi x1, x0, 0x01
  addi x2, x0, 0x01
  addi x3, x0, 0x04
  addi x4, x0, 0x05
  addi x5, x0, 0x01
  addi x6, x0, 0x04
  addi x7, x0, 114
  ebreak
#  lui sp, 0x9FFFF
#  j main
