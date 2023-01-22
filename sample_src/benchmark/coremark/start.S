.section .text.init
.global _start
_start:
  li sp, 0x3000

# jump to main()
  jal ra, main

  ebreak
