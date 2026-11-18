#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if (((f32bits >> 23) & 0xFF) == 0xFF)
        return (uint16_t) (f32bits >> 16);
    /* round to nearest, ties to even */
    f32bits += 0x7FFF + ((f32bits >> 16) & 1);
    return (uint16_t) (f32bits >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    uint16_t sign = (a ^ b) & 0x8000;
    int ea = (a >> 7) & 0xFF, eb = (b >> 7) & 0xFF;
    uint32_t ma = a & 0x7F, mb = b & 0x7F;

    if (ea == 0xFF) {
        if (ma)
            return a;
        if (!(b & 0x7FFF))
            return 0x7FC0;
        return sign | 0x7F80;
    }
    if (eb == 0xFF) {
        if (mb)
            return b;
        if (!(a & 0x7FFF))
            return 0x7FC0;
        return sign | 0x7F80;
    }
    if (!(a & 0x7FFF) || !(b & 0x7FFF))
        return sign;

    /* denormals: shift the leading one up to bit 7 */
    if (ea)
        ma |= 0x80;
    else
        for (ea = 1; !(ma & 0x80); ea--)
            ma <<= 1;
    if (eb)
        mb |= 0x80;
    else
        for (eb = 1; !(mb & 0x80); eb--)
            mb <<= 1;

    uint32_t p = ma * mb;
    int exp = ea + eb - 127;
    if (p & 0x8000) {
        p >>= 8;
        exp++;
    } else {
        p >>= 7;
    }
    p &= 0x7F;

    if (exp >= 0xFF)
        return sign | 0x7F80;
    if (exp <= 0) {
        if (exp < -6)
            return sign;
        return sign | (uint16_t) (p >> (1 - exp));
    }
    return sign | (uint16_t) (exp << 7) | (uint16_t) p;
}

uint16_t bf16_sqrt(uint16_t a)
{
    int exp = (a >> 7) & 0xFF;
    uint32_t mant = a & 0x7F;

    if (exp == 0xFF) {
        if (mant || !(a & 0x8000))
            return a;
        return 0x7FC0;
    }
    if (!(a & 0x7FFF))
        return 0;
    if (a & 0x8000)
        return 0x7FC0;
    if (!exp)
        return 0;

    /* even exponent field = odd unbiased exponent: double m first */
    uint32_t m = 0x80 | mant;
    if (!(exp & 1))
        m <<= 1;
    int new_exp = (exp + 127) >> 1;

    uint32_t lo = 90, hi = 256, r = 128;
    while (lo <= hi) {
        uint32_t mid = (lo + hi) >> 1;
        if (mid * mid / 128 <= m) {
            r = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    /* m in [128, 510] keeps r in [128, 255] and new_exp in [64, 190] */
    return (uint16_t) (new_exp << 7) | (uint16_t) (r & 0x7F);
}
