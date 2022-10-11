.section .text.init
.global _start
_start:
  #li sp, 0x4000
  #jal ra, main
  li x1, 0x1234
  csrrw x2, 0x00, x1
  csrrw x3, 0x00, x4
  ebreak
