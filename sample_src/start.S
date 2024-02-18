.section .text.init
.global _start
_start:
  jal x1, func
  addi x2, x0, 0
  addi x3, x0, 0
  addi x4, x0, 1
  addi x5, x0, 4

.loop:
  addi x2, x3, 0
  addi x3, x4, 0
  add x4, x2, x3
  addi x5, x5, -1
  bne x5, x0, .loop
  
  li x6, 0xcafebabe
  li x7, 0xdeadbeef

  jalr x0, x0, 0

func:
  addi x8, x0, 0
  addi x9, x0, 0
  addi x10, x0, 1
  addi x11, x0, 4
  jalr x0, x1, 0
