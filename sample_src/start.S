.section .text.init
.global _start
_start:

  addi x1, x0, 10
.loop:
  addi x1, x1, -1
  bne  x1, x0, .loop
  ebreak
#  lui sp, 0x9FFFF
#  j main
