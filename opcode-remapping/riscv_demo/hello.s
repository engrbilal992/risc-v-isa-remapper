	.text
	.attribute	4, 16
	.attribute	5, "rv64i2p0_m2p0_a2p0_f2p0_d2p0_c2p0"
	.file	"hello.c"
	.globl	_start                          # -- Begin function _start
	.p2align	1
	.type	_start,@function
_start:                                 # @_start
# %bb.0:
	addi	sp, sp, -48
	sd	ra, 40(sp)                      # 8-byte Folded Spill
	sd	s0, 32(sp)                      # 8-byte Folded Spill
	addi	s0, sp, 48
	li	a0, 5
	sw	a0, -20(s0)
	li	a0, 10
	sw	a0, -24(s0)
	lw	a0, -20(s0)
	lw	a1, -24(s0)
	addw	a0, a0, a1
	sw	a0, -28(s0)
	sd	zero, -40(s0)
	li	a0, 93
	sd	a0, -48(s0)
	ld	a0, -40(s0)
	ld	a7, -48(s0)
	#APP
	ecall	
	#NO_APP
	ld	ra, 40(sp)                      # 8-byte Folded Reload
	ld	s0, 32(sp)                      # 8-byte Folded Reload
	addi	sp, sp, 48
	ret
.Lfunc_end0:
	.size	_start, .Lfunc_end0-_start
                                        # -- End function
	.ident	"Ubuntu clang version 14.0.0-1ubuntu1.1"
	.section	".note.GNU-stack","",@progbits
