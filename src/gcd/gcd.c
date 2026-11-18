#include "gcd.h"

/* x != 0 */
static inline int ctz(uint32_t x)
{
    int n = 0;
    if ((x & 0xffff) == 0) {
        n += 16;
        x >>= 16;
    }
    if ((x & 0xff) == 0) {
        n += 8;
        x >>= 8;
    }
    if ((x & 0xf) == 0) {
        n += 4;
        x >>= 4;
    }
    if ((x & 0x3) == 0) {
        n += 2;
        x >>= 2;
    }
    return n + !(x & 1);
}

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (a == 0)
        return b;
    if (b == 0)
        return a;

    /* shared factors of 2 */
    int k = 0;
    if (((a | b) & 1) == 0)
        k = ctz(a | b);
    if ((a & 1) == 0)
        a >>= ctz(a);
    if ((b & 1) == 0)
        b >>= ctz(b);

    /* both odd: b - a is even */
    for (;;) {
        if (a > b) {
            uint32_t t = a;
            a = b;
            b = t;
        }
        b -= a;
        if (b == 0)
            break;
        do
            b >>= 1;
        while ((b & 1) == 0);
    }
    return a << k;
}
