# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
# Scratch: t0, t1, t5, t6, a2.
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .option push
    .option norelax                 # keep auipc + %pcrel_lo as written

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    andi    t0, a1, 1
.Lpc:
    auipc   t6, %pcrel_hi(.Lctz8)
    beqz    t0, .Lb_even
    andi    t1, a0, 1               # b odd
    beqz    t1, .La_strip
    bltu    a0, a1, .Lb_sub

.La_sub:                            # a >= b
    sub     a0, a0, a1
.La_strip:
    andi    t0, a0, 0xff
    beqz    t0, .La_slow
    add     t0, t0, t6
    lbu     t0, %pcrel_lo(.Lpc)(t0) # ctz of low byte
    srl     a0, a0, t0
    bgeu    a0, a1, .La_sub

.Lb_sub:                            # b >= a
    sub     a1, a1, a0
.Lb_strip:
    andi    t0, a1, 0xff
    beqz    t0, .Lb_slow
    add     t0, t0, t6
    lbu     t0, %pcrel_lo(.Lpc)(t0)
    srl     a1, a1, t0
    bgeu    a1, a0, .Lb_sub
    j       .La_sub

.La_slow:
    beqz    a0, .Lret_b             # a == b
1:
    srli    a0, a0, 8
    andi    t0, a0, 0xff
    beqz    t0, 1b
    add     t0, t0, t6
    lbu     t0, %pcrel_lo(.Lpc)(t0)
    srl     a0, a0, t0
    bgeu    a0, a1, .La_sub
    j       .Lb_sub

.Lb_slow:
    beqz    a1, .Lret               # a == b
1:
    srli    a1, a1, 8
    andi    t0, a1, 0xff
    beqz    t0, 1b
    add     t0, t0, t6
    lbu     t0, %pcrel_lo(.Lpc)(t0)
    srl     a1, a1, t0
    bgeu    a1, a0, .Lb_sub
    j       .La_sub

.Lret_b:
    mv      a0, a1
.Lret:
    ret

.Lb_even:
    beqz    a1, .Lret               # gcd(a, 0)
    andi    t1, a0, 1
    bnez    t1, .Lb_strip
    beqz    a0, .Lret_b             # gcd(0, b)
    or      t1, a0, a1              # k = ctz(a | b)
    li      a2, 0
1:
    andi    t0, t1, 0xff
    bnez    t0, 2f
    srli    t1, t1, 8
    addi    a2, a2, 8
    j       1b
2:
    add     t0, t0, t6
    lbu     t0, %pcrel_lo(.Lpc)(t0)
    add     a2, a2, t0
    srl     a0, a0, a2
    srl     a1, a1, a2
    mv      t5, ra                  # run the loop, then shift back by k
    andi    t0, a1, 1
    bnez    t0, 3f
    jal     .Lb_strip
    sll     a0, a0, a2
    jr      t5
3:
    jal     .La_strip
    sll     a0, a0, a2
    jr      t5
    .size   gcd_u32_asm, .-gcd_u32_asm

# ctz of 1..255, entry 0 unused
    .section .rodata
.Lctz8:
    .byte   0, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   7, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   6, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   5, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    .byte   4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0

    .option pop
