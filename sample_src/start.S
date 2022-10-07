.section .text.init
.global _start
_start:
  li x10, 0x1000
  sw x10, 10(x0)
  lh x15, 10(x0)
  ebreak
