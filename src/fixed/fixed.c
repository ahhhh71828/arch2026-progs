#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int k = 0;
    while (b) {
        uint32_t c = (a & b) << 1;
        a ^= b;
        b = c;
        k++;
    }
    *n = k;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

/* shared bits plus half of the differing bits */
uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t neg = (uint32_t) (a ^ b) >> 31;
    uint32_t x = a < 0 ? 0u - (uint32_t) a : (uint32_t) a;
    uint32_t y = b < 0 ? 0u - (uint32_t) b : (uint32_t) b;

    /* hi:lo = x * y, one bit of y per step; hi < x <= 2^31, no carry out */
    uint32_t hi = 0, lo = y;
    for (int i = 0; i < 32; i++) {
        if (lo & 1)
            hi += x;
        lo = (lo >> 1) | (hi << 31);
        hi >>= 1;
    }

    /* -p rounds up too: (-p + 2^19) >> 20 = -((p + 2^19 - 1) >> 20) */
    uint32_t c = (1u << 19) - neg;
    lo += c;
    hi += lo < c;
    uint32_t r = (hi << 12) | (lo >> 20);
    return (int32_t) (neg ? 0u - r : r);
}
