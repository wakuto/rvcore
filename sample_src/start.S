.section .text.init
.global _start
_start:
  li sp, 0x4000
  jal ra, main
  ebreak
