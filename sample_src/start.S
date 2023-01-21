.section .text.init
.global _start
_start:
  li sp, 0x3000
  sw sp, -4(sp)
  lw x10, -4(sp)
  csrrs   x1,minstret,x0
  csrrs   x1,minstret,x0
  csrrs   x2,mcycle,x0
  csrrs   x2,mcycle,x0
  li sp, 0x3000
#   la t0, _trap_vec
# # interrupt enable
#   csrrsi t1, mstatus, 0x8
# # timer & external interrupt enable
#   li t1, 0x888
#   csrrs t1, mie, t1
# # trap vector configuration
#   csrrw t1, mtvec, t0

# jump to main()
  jal ra, main
  csrrs   x1,minstret,x0
  csrrs   x1,minstret,x0
  csrrs   x2,mcycle,x0
  csrrs   x2,mcycle,x0
  li x3, 0x10000000
  li x2, 0x48
  sw x2, 0(x3)
  li x2, 0x65
  sw x2, 0(x3)
  li x2, 0x6c
  sw x2, 0(x3)
  li x2, 0x6c
  sw x2, 0(x3)
  li x2, 0x6f
  sw x2, 0(x3)


  ebreak


_ecall_func:
  nop
  nop
  nop
  mret

_trap_vec:
  sw t2, -4(sp)
  sw t3, -8(sp)
  csrrs t2, mcause, x0
  li t3, 0x80000000
  and t2, t2, t3
  bne t2, x0, .interrupt

# if exception: mepc += 4
  csrrs t2, mepc, x0
  addi t2, t2, 4
  csrrw t2, mepc, t2

.interrupt:
  li x1, 0xdeadbeef

  lw t3, -8(sp)
  lw t2, -4(sp)
  mret
