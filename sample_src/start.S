.section .text.init
.global _start
_start:
  addi x1, x0, 0x01
  addi x2, x0, 0x02
  addi x3, x0, 0x03
  lb   x4, 0x14(x0)
  lw   x5, 0x14(x0)
  ebreak
#  lui sp, 0x9FFFF
#  j main
