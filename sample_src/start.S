.section .text.init
.global _start
_start:
  addi x1, x0, 0x01
  addi x2, x0, 0x02
  addi x3, x0, 0x03
  li   x4, 0xdeadbeef
  sw   x4, 0x14(x0)
  lb   x5, 0x20(x0)
  lw   x6, 0x14(x0)
  ebreak
#  lui sp, 0x9FFFF
#  j main
