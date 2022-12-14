.section .text.init
.global _start
_start:
  li sp, 0x4000
  # jal ra, main
  la t0, _trap_vec
# interrupt enable
  csrrsi t1, mstatus, 0x8
# trap vector configuration
  csrrw t1, mtvec, t0
  ecall
  ebreak


_ecall_func:
  nop
  nop
  nop
  mret

_trap_vec:
  li a0, 0xdeadbeef
  csrrs t2, mepc, x0
  addi t2, t2, 4
  csrrw t3, mepc, t2
  mret
