.section .text.init
.global _start
_start:
  #li sp, 0x4000
  #jal ra, main

  li x1, 0x8
  la x2, _ecall_func
  li x4, 0x80000000
  csrrs x3, 0x300, x1   # mstatus.mie = 1
  csrrs x3, 0x304, x1   # mie.msie = 1
  csrrw x3, 0x305, x2   # mtvec = _ecall_func
  csrrs x3, 0x342, x4   # mcause = 0x80000000
  csrrs x3, 0x344, x1   # mip.msip = 1  interrupt!!
  li x1, 0x1
  li x2, 0x2
  li x3, 0x3
  li x4, 0x4
  li x5, 0x5
  li x6, 0x6
  li x7, 0x7
  li x8, 0x8
  li x9, 0x9
  ebreak


_ecall_func:
  nop
  nop
  nop
  mret
