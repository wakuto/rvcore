	.file	"test.c"
	.option nopic
	.attribute arch, "rv32i2p1_zicsr2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	2
	.globl	putch
	.type	putch, @function
putch:
	addi	sp,sp,-48
	sw	s0,44(sp)
	addi	s0,sp,48
	mv	a5,a0
	sb	a5,-33(s0)
	li	a5,268435456
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	lbu	a4,-33(s0)
	sb	a4,0(a5)
	nop
	lw	s0,44(sp)
	addi	sp,sp,48
	jr	ra
	.size	putch, .-putch
	.align	2
	.globl	putstr
	.type	putstr, @function
putstr:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	sw	a0,-20(s0)
	j	.L3
.L4:
	lw	a5,-20(s0)
	lbu	a5,0(a5)
	mv	a0,a5
	call	putch
	lw	a5,-20(s0)
	addi	a5,a5,1
	sw	a5,-20(s0)
.L3:
	lw	a5,-20(s0)
	lbu	a5,0(a5)
	bne	a5,zero,.L4
	nop
	nop
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	putstr, .-putstr
	.align	2
	.globl	fibonacchi
	.type	fibonacchi, @function
fibonacchi:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	sw	s1,20(sp)
	addi	s0,sp,32
	sw	a0,-20(s0)
	lw	a5,-20(s0)
	bne	a5,zero,.L6
	li	a5,0
	j	.L7
.L6:
	lw	a4,-20(s0)
	li	a5,1
	beq	a4,a5,.L8
	lw	a4,-20(s0)
	li	a5,2
	bne	a4,a5,.L9
.L8:
	li	a5,1
	j	.L7
.L9:
	lw	a5,-20(s0)
	addi	a5,a5,-1
	mv	a0,a5
	call	fibonacchi
	mv	s1,a0
	lw	a5,-20(s0)
	addi	a5,a5,-2
	mv	a0,a5
	call	fibonacchi
	mv	a5,a0
	add	a5,s1,a5
.L7:
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	addi	sp,sp,32
	jr	ra
	.size	fibonacchi, .-fibonacchi
	.section	.rodata
	.align	2
.LC0:
	.string	"Hello from C!\n"
	.text
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	li	a0,7
	call	fibonacchi
	sw	a0,-20(s0)
	lui	a5,%hi(.LC0)
	addi	a0,a5,%lo(.LC0)
	call	putstr
	lw	a5,-20(s0)
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	main, .-main
	.ident	"GCC: () 12.2.0"
