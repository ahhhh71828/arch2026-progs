# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
# Scratch: t0, t1, t6, a2.
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    beqz    a1, .Lop1_n0
    .irp    k, 1, 2, 3, 4, 5, 6, 7, 8
    and     t0, a0, a1
    xor     a0, a0, a1
    slli    a1, t0, 1
    beqz    a1, .Lop1_n\k
    .endr
    li      t1, 8                   # long carry chain: count in a loop
1:
    and     t0, a0, a1
    xor     a0, a0, a1
    slli    a1, t0, 1
    addi    t1, t1, 1
    bnez    a1, 1b
    sw      t1, 0(a2)
    ret
.Lop1_n0:
    sw      zero, 0(a2)
    ret
    .irp    k, 1, 2, 3, 4, 5, 6, 7, 8
.Lop1_n\k:
    li      t0, \k
    sw      t0, 0(a2)
    ret
    .endr
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1
    xor     a0, a0, a1
    srli    a0, a0, 1
    add     a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

# One multiplier bit: hi:lo = (hi + (lo & 1 ? x : 0)) : lo, shifted right by 1.
# hi < x <= 2^31 throughout, so hi + x never carries out.
.macro QBIT
    andi    t0, a1, 1
    beqz    t0, 1f
    add     a2, a2, a0
1:
    srli    a1, a1, 1
    slli    t0, a2, 31
    or      a1, a1, t0
    srli    a2, a2, 1
.endm

# One multiplier byte; n bits are done after it. A zero byte is one shift.
.macro QBYTE n
    andi    t0, a1, 0xff
    bnez    t0, 2f
    srli    a1, a1, 8
    slli    t0, a2, 24
    or      a1, a1, t0
    srli    a2, a2, 8
    j       3f
2:
    .rept   8
    QBIT
    .endr
3:
    .if     \n < 32
    slli    t0, a1, \n              # rest of the multiplier
    beqz    t0, .Lq_exit\n
    .endif
.endm

# Multiplier ran out after n bits: hi:lo >>= 32 - n.
.macro QEXIT n
.Lq_exit\n:
    srli    a1, a1, 32 - \n
    slli    t0, a2, \n
    or      a1, a1, t0
    srli    a2, a2, 32 - \n
    j       .Lq_round
.endm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    xor     t6, a0, a1
    srai    t6, t6, 31              # -1 if the product is negative
    srai    t0, a0, 31
    xor     a0, a0, t0
    sub     a0, a0, t0
    srai    t0, a1, 31
    xor     a1, a1, t0
    sub     a1, a1, t0
    bgeu    a0, a1, 1f
    mv      t0, a0                  # x = larger, y = smaller magnitude
    mv      a0, a1
    mv      a1, t0
1:
    beqz    a1, .Lq_zero
    li      a2, 0                   # a2:a1 = hi:lo, lo starts as y
    QBYTE   8
    QBYTE   16
    QBYTE   24
    QBYTE   32
.Lq_round:
    li      t0, 0x80000
    add     t0, t0, t6              # 2^19, or 2^19 - 1 for -p
    add     a1, a1, t0
    sltu    t0, a1, t0
    add     a2, a2, t0
    srli    a1, a1, 20
    slli    a2, a2, 12
    or      a0, a1, a2
    xor     a0, a0, t6
    sub     a0, a0, t6
    ret
.Lq_zero:
    li      a0, 0
    ret
    QEXIT   8
    QEXIT   16
    QEXIT   24
    .size   q_mul_asm, .-q_mul_asm
