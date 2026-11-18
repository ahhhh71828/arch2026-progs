# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
# Scratch: t0-t6.
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .option push
    .option norelax                 # keep auipc + %pcrel_lo as written

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    slli    t0, a0, 1
    lui     t1, 0xff000
    bgeu    t0, t1, 1f              # Inf or NaN: top half as is
    srli    t0, a0, 16
    andi    t0, t0, 1
    add     a0, a0, t0
    lui     t1, 8
    addi    t1, t1, -1
    add     a0, a0, t1              # + 0x7fff + bit 16
1:
    srli    a0, a0, 16
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    xor     t6, a0, a1
    srli    t6, t6, 15
    slli    t6, t6, 15              # sign
    srli    t0, a0, 7
    andi    t0, t0, 0xff
    srli    t1, a1, 7
    andi    t1, t1, 0xff
    andi    t2, a0, 0x7f
    andi    t3, a1, 0x7f
    li      t4, 254
    bltu    t4, t0, .Lmul_a_ff
    bltu    t4, t1, .Lmul_b_ff
    beqz    t0, .Lmul_a_sub
.Lmul_a_ok:
    beqz    t1, .Lmul_b_sub
.Lmul_b_ok:
    add     t0, t0, t1
    addi    t0, t0, -128            # exponent - 1
    # ma * mb = sq[ma + mb] - sq[ma - mb]
.Lmul_pc:
    auipc   t5, %pcrel_hi(.Lsq)
    add     t1, t2, t3
    addi    t1, t1, 256             # ma + mb with the hidden ones
    sub     t3, t2, t3
    slli    t1, t1, 1
    slli    t3, t3, 1
    add     t1, t1, t5
    add     t3, t3, t5
    lhu     t1, %pcrel_lo(.Lmul_pc)(t1)
    lhu     t3, %pcrel_lo(.Lmul_pc)(t3)
    sub     t2, t1, t3
    srli    t1, t2, 15
    add     t0, t0, t1
    addi    t1, t1, 7
    srl     t2, t2, t1              # 1.fffffff, truncated
    bltz    t0, .Lmul_under
    bge     t0, t4, .Lmul_inf
    slli    t0, t0, 7
    add     t0, t0, t2              # hidden one adds the 1 back
    or      a0, t0, t6
    ret

.Lmul_a_sub:
    beqz    t2, .Lmul_zero
    li      t0, 1
1:
    slli    t2, t2, 1
    addi    t0, t0, -1
    andi    t5, t2, 0x80
    beqz    t5, 1b
    andi    t2, t2, 0x7f
    j       .Lmul_a_ok

.Lmul_b_sub:
    beqz    t3, .Lmul_zero
    li      t1, 1
1:
    slli    t3, t3, 1
    addi    t1, t1, -1
    andi    t5, t3, 0x80
    beqz    t5, 1b
    andi    t3, t3, 0x7f
    j       .Lmul_b_ok

.Lmul_under:                        # exponent <= 0
    addi    t1, t0, 7
    bltz    t1, .Lmul_zero          # below -6
    andi    t2, t2, 0x7f
    neg     t0, t0
    srl     t2, t2, t0              # >> (1 - exponent)
    or      a0, t2, t6
    ret

.Lmul_a_ff:
    bnez    t2, .Lmul_ret           # NaN a
    slli    t5, a1, 17
    beqz    t5, .Lmul_nan           # Inf * 0
    j       .Lmul_inf
.Lmul_b_ff:
    bnez    t3, .Lmul_ret_b
    slli    t5, a0, 17
    beqz    t5, .Lmul_nan
.Lmul_inf:
    li      t5, 0x7f80
    or      a0, t6, t5
    ret
.Lmul_nan:
    li      a0, 0x7fc0
    ret
.Lmul_ret_b:
    mv      a0, a1
.Lmul_ret:
    ret
.Lmul_zero:
    mv      a0, t6
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    srli    t0, a0, 7               # sign and exponent
    addi    t1, t0, -1
    li      t2, 253
    bltu    t2, t1, .Lsqrt_special  # not a positive normal
    addi    t0, t0, 127
    srli    t0, t0, 1
.Lsqrt_pc:
    auipc   t2, %pcrel_hi(.Lsqrt_frac)
    andi    t1, a0, 0xff            # exponent parity and fraction
    add     t1, t1, t2
    lbu     t1, %pcrel_lo(.Lsqrt_pc)(t1)
    slli    t0, t0, 7
    or      a0, t0, t1
    ret
.Lsqrt_special:
    beqz    t0, .Lsqrt_zero         # +0, +denormal
    li      t2, 255
    beq     t0, t2, .Lsqrt_ret      # +Inf, +NaN
    lui     t2, 8
    beq     a0, t2, .Lsqrt_zero     # -0
    li      t2, 0xff80
    bltu    t2, a0, .Lsqrt_ret      # -NaN
    li      a0, 0x7fc0
    ret
.Lsqrt_zero:
    li      a0, 0
.Lsqrt_ret:
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm

    .section .rodata

# sq[n] = n * n / 4, -127 <= n <= 510
    .align  1
    .set    n, -127
    .rept   127
    .half   n * n / 4
    .set    n, n + 1
    .endr
.Lsq:
    .rept   511
    .half   n * n / 4
    .set    n, n + 1
    .endr

# sqrt fraction by low byte (exponent parity, fraction), as bf16.h defines
# it: the largest mid in [90, 256] with mid * mid / 128 <= m
.Lsqrt_frac:
    .set    i, 0
    .rept   256
    .set    m, (0x80 | (i & 0x7f)) << (1 - (i >> 7))   # doubled if exp even
    .set    mid, 90
    .rept   167
    .if     mid * mid / 128 <= m
    .set    r, mid
    .endif
    .set    mid, mid + 1
    .endr
    .byte   r & 0x7f
    .set    i, i + 1
    .endr

    .option pop
