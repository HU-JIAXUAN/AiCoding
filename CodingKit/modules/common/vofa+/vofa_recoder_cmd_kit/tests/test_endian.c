/**
 * @file    test_endian.c
 * @brief   大端表示的换序及跨帧借用验证
 * @details 主机以大端对象字节模拟输入，期望线序由独立小端字面量给出
 * @author  HU JIAXUAN
 * @date    2026-10-29
 * @version 1.0.0
 */
#include "vofa.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition)                                                                                               \
    do {                                                                                                               \
        if (!(condition)) {                                                                                            \
            fprintf(stderr, "FAIL test_endian:%d: %s\n", __LINE__, #condition);                                        \
            exit(1);                                                                                                   \
        }                                                                                                              \
    } while (0)

static const uint8_t *pending;
static size_t pendingLength;
static uint8_t snapshot[4];
static uint8_t wire[256];
static size_t wireLength;
static unsigned refuse;

static void complete_segment(void);

/* 源由发送接口借用到显式完成，不允许准备下一值时改写在途槽 */
bool example_transport_send(const uint8_t *addr, size_t length)
{
    if (pending != NULL) {
        CHECK(memcmp(pending, snapshot, sizeof(snapshot)) == 0);
        return false;
    }
    if (refuse != 0u) {
        refuse--;
        return false;
    }
    CHECK(length == sizeof(snapshot));
    pending = addr;
    pendingLength = length;
    memcpy(snapshot, addr, length);
    return true;
}

/* 完成时取真实槽内容，检查借用期间一直保持 */
static void complete_segment(void)
{
    CHECK(pending != NULL && wireLength + pendingLength <= sizeof(wire));
    CHECK(memcmp(pending, snapshot, pendingLength) == 0);
    memcpy(wire + wireLength, pending, pendingLength);
    wireLength += pendingLength;
    pending = NULL;
}

int main(void)
{
    static const union {
        uint32_t alignment[4];
        uint8_t bytes[16];
    } source = {.bytes = {
                    0x3fu, 0x80u, 0x00u, 0x00u, /* 1.0 */
                    0xc0u, 0x20u, 0x00u, 0x00u, /* -2.5 */
                    0x40u, 0x60u, 0x00u, 0x00u, /* 3.5 */
                    0x3eu, 0x80u, 0x00u, 0x00u  /* 0.25 */
                }};
    static const uint8_t expected[] = {0x00u, 0x00u, 0x80u, 0x3fu, 0x00u, 0x00u, 0x20u, 0xc0u,
                                       0x00u, 0x00u, 0x60u, 0x40u, 0x00u, 0x00u, 0x80u, 0x3eu};
    static const size_t counts[] = {3u, 2u, 1u, 4u, 0u, 3u};
    static const uint8_t tail[] = {0x00u, 0x00u, 0x80u, 0x7fu};
    const float *values = (const float *)(const void *)source.bytes;
    size_t frame, value, start;

    CHECK(VOFA_BIG_ENDIAN == 1u && sizeof(float) == 4u);
    for (frame = 0u; frame < sizeof(counts) / sizeof(counts[0]); frame++) {
        start = wireLength;
        for (value = 0u; value < counts[frame]; value++) {
            CHECK(!vofa_send(values, counts[frame]) && pending != NULL);
            CHECK(!vofa_send(values, counts[frame]));
            CHECK(!vofa_send(values, counts[frame]));
            CHECK(memcmp(pending, expected + value * 4u, 4u) == 0);
            complete_segment();
        }
        refuse = 1u; /* 末值完成后尾部拒绝，不能重新发送已提交数值 */
        CHECK(!vofa_send(values, counts[frame]) && pending == NULL);
        CHECK(vofa_send(values, counts[frame]) && pending != NULL);
        CHECK(memcmp(pending, tail, sizeof(tail)) == 0);
        if (frame + 1u < sizeof(counts) / sizeof(counts[0])) {
            /* 下一帧在旧尾部占用期间重试，转换槽和尾部都应保持 */
            CHECK(!vofa_send(values, counts[frame + 1u]));
        }
        complete_segment();
        CHECK(wireLength - start == counts[frame] * 4u + sizeof(tail));
        CHECK(memcmp(wire + start, expected, counts[frame] * 4u) == 0);
        CHECK(memcmp(wire + start + counts[frame] * 4u, tail, sizeof(tail)) == 0);
    }
    puts("PASS: big-endian bytes, odd/even/zero frames, tail refusal and immutable in-flight slots");
    return 0;
}
