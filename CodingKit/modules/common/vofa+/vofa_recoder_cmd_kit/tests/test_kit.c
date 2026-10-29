/**
 * @file    test_kit.c
 * @brief   完整模块的命令、采集和异步生命周期验证
 * @details 发送替身借用原地址，显式完成后才读数据并接受下一段
 * @author  HU JIAXUAN
 * @date    2026-10-29
 * @version 1.0.0
 */
#include "vofa.h"
#include "recorder.h"
#include "example_business.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition)                                                                                               \
    do {                                                                                                               \
        if (!(condition)) {                                                                                            \
            fprintf(stderr, "FAIL test_kit:%d: %s\n", __LINE__, #condition);                                           \
            exit(1);                                                                                                   \
        }                                                                                                              \
    } while (0)

static const uint8_t *pending;
static size_t pendingLength;
static uint8_t borrowedBytes[2048];
static uint8_t wire[8192];
static size_t wireLength;
static unsigned refuse;
static unsigned submissions;
static unsigned readBlock;
static size_t readOffset;

static void complete_segment(void);
static bool pump(void);
static void test_commands(void);
static void test_capture_and_send(void);

/* 旧段释放前拒绝新段；接受时不复制，测试快照只用于检查源未覆写 */
bool example_transport_send(const uint8_t *addr, size_t length)
{
    if (pending != NULL) {
        CHECK(memcmp(pending, borrowedBytes, pendingLength) == 0);
        return false;
    }
    if (refuse != 0u) {
        refuse--;
        return false;
    }
    CHECK(length > 0u && length <= sizeof(borrowedBytes));
    pending = addr;
    pendingLength = length;
    memcpy(borrowedBytes, addr, length);
    submissions++;
    return true;
}

/* 完成时才从被借用的真实地址取字节 */
static void complete_segment(void)
{
    CHECK(pending != NULL && wireLength + pendingLength <= sizeof(wire));
    CHECK(memcmp(pending, borrowedBytes, pendingLength) == 0);
    memcpy(wire + wireLength, pending, pendingLength);
    wireLength += pendingLength;
    pending = NULL;
}

/* 应用消费完成块；完成一组才前进，整块消费后才归还 */
static bool pump(void)
{
    RecorderBlock *block = &g_recorderBlocks[readBlock];

    if (!block->ready) {
        return false;
    }
    __atomic_signal_fence(__ATOMIC_ACQ_REL);
    if (!vofa_send(block->addr + readOffset, mDecodePtrCount)) {
        return false;
    }
    readOffset += mDecodePtrCount;
    if (readOffset == block->count) {
        __atomic_signal_fence(__ATOMIC_ACQ_REL);
        block->ready = false;
        readOffset = 0u;
        readBlock ^= 1u;
    }
    return true;
}

/* 独立期望值覆盖名称/数值语法、精确整数、状态与业务动作 */
static void test_commands(void)
{
    char frames[] = " demo.mode : 1 \0 demo.setting : 3.25 \0";
    char badFrame[] = "demo.setting=99";

    CHECK(command_parse("missing", "1") == MC_UNKNOWN);
    CHECK(command_parse("demo.runOnly", "2") == MC_BAD_STATE);
    vofa_parse(frames, strlen(frames));
    CHECK(exampleRam.state == EXAMPLE_RUN);
    vofa_parse(frames + sizeof(" demo.mode : 1 "), strlen(frames + sizeof(" demo.mode : 1 ")));
    CHECK(exampleRam.setting == 3.25f);
    vofa_parse(badFrame, strlen(badFrame));
    CHECK(exampleRam.setting == 3.25f);
    CHECK(command_parse("demo.offset", "0.5") == MC_OK && exampleRam.setting == 3.75f);
    CHECK(command_parse("demo.position", "9007199254740993") == MC_OK &&
          exampleRam.position == INT64_C(9007199254740993));
    CHECK(command_parse("demo.position", "9223372036854775807") == MC_OK && exampleRam.position == INT64_MAX);
    CHECK(command_parse("demo.position", "-9223372036854775808") == MC_OK && exampleRam.position == INT64_MIN);
    CHECK(command_parse("demo.position", "9223372036854775808") == MC_BAD_VALUE);
    CHECK(command_parse("demo.position", "-9223372036854775809") == MC_BAD_VALUE);
    CHECK(command_parse("demo.position", "3.5") == MC_BAD_VALUE);
    CHECK(command_parse("demo.level", "255") == MC_OK && exampleRam.level == 255u);
    CHECK(command_parse("demo.level", "256") == MC_BAD_VALUE);
    CHECK(command_parse("demo.level", "-1") == MC_BAD_VALUE);
    CHECK(command_parse("demo.word", "2147483647") == MC_OK && exampleRam.signedWord == INT32_MAX);
    CHECK(command_parse("demo.word", "-2147483648") == MC_OK && exampleRam.signedWord == INT32_MIN);
    CHECK(command_parse("demo.word", "2147483648") == MC_BAD_VALUE);
    CHECK(command_parse("demo.setting", "nan") == MC_BAD_VALUE);
    CHECK(command_parse("demo.setting", "inf") == MC_BAD_VALUE);
    CHECK(command_parse("demo.setting", "1junk") == MC_BAD_VALUE);
    CHECK(command_parse("demo.setting", "") == MC_BAD_VALUE);
    CHECK(command_parse("demo.mode", "256") == MC_BAD_VALUE);
    CHECK(command_parse("demo.mode", "2") == MC_OK);
    CHECK(command_parse("demo.setting", "1") == MC_BAD_STATE);
    CHECK(command_parse("demo.offset", "1") == MC_BAD_STATE);
    CHECK(command_parse("demo.readonly", "0") == MC_READ_ONLY);
    CHECK(command_parse("demo.mode", "0") == MC_OK);
    CHECK(command_parse("demo.runOnly", "1") == MC_BAD_STATE);
    CHECK(command_parse("demo.mode", "1") == MC_OK);
    CHECK(command_parse("demo.runOnly", "1.25") == MC_OK && exampleRam.setting == 1.25f);
    puts("PASS: complete-frame syntax, exact int64, storage types, RO, states and actions");
}

/* 数据段或帧尾被拒绝时都不推进应用进度；只在尾部接受后允许归还 */
static void test_capture_and_send(void)
{
    const float expected[] = {
        255.0f, 30000.0f, -308.5f, (float)-123456789, (float)UINT32_C(0xf1234567), (float)INT64_C(9007199254740993),
        2.5f};
    const uint8_t tail[] = {0x00u, 0x00u, 0x80u, 0x7fu};
    size_t capacity = g_recorderBlocks[0].count;
    size_t groups = capacity / mDecodePtrCount;
    size_t row, channel;
    unsigned before;

    exampleRam.signedWord = -123456789;
    exampleRam.position = INT64_C(9007199254740993);
    CHECK(mDecodePtrCount == sizeof(expected) / sizeof(expected[0]) && groups > 1u);
    for (row = 0u; row < groups - 1u; row++) {
        recorder();
        CHECK(!g_recorderBlocks[0].ready);
    }
    recorder();
    CHECK(g_recorderBlocks[0].ready && g_recorderBlocks[0].count == groups * mDecodePtrCount);
    CHECK(g_recorderBlocks[0].addr != g_recorderBlocks[1].addr);
    for (channel = 0u; channel < mDecodePtrCount; channel++) {
        CHECK(g_recorderBlocks[0].addr[channel] == expected[channel]);
    }
    for (row = 0u; row < groups; row++) {
        recorder();
    }
    CHECK(g_recorderBlocks[1].ready);
    refuse = 1u;
    CHECK(!pump() && pending == NULL && readOffset == 0u && g_recorderBlocks[0].ready);
    for (row = 0u; row < 2u * groups; row++) {
        RecorderBlock *block = &g_recorderBlocks[readBlock];
        size_t savedOffset = readOffset;
        const float *source = block->addr + savedOffset;
        bool lastGroup = savedOffset + mDecodePtrCount == block->count;

        CHECK(!pump() && pending == (const uint8_t *)source);
        CHECK(pendingLength == mDecodePtrCount * sizeof(float));
        CHECK(block->ready && readOffset == savedOffset);
        CHECK(!pump() && readOffset == savedOffset);
        if (row == 0u) {
            exampleRam.setting = 9.0f;
            recorder(); /* 两块都在使用，采集不得覆写旧块 */
            CHECK(source[6] == 2.5f);
            exampleRam.setting = 1.25f;
        }
        complete_segment();
        refuse = 1u;
        CHECK(!pump() && pending == NULL && block->ready && readOffset == savedOffset);
        CHECK(pump() && pendingLength == sizeof(tail));
        CHECK(memcmp(pending, tail, sizeof(tail)) == 0);
        CHECK(block->ready == !lastGroup);
        if (row == groups - 1u) {
            recorder(); /* 尾部仍在发送，源块已经可以开始复用 */
            CHECK(!block->ready);
        }
        complete_segment();
        CHECK(memcmp(wire + row * (sizeof(expected) + sizeof(tail)), expected, sizeof(expected)) == 0);
        CHECK(memcmp(wire + row * (sizeof(expected) + sizeof(tail)) + sizeof(expected), tail, sizeof(tail)) == 0);
    }
    CHECK(!g_recorderBlocks[0].ready && !g_recorderBlocks[1].ready && !pump());
    CHECK(wireLength == 2u * groups * (sizeof(expected) + sizeof(tail)));
    before = submissions;
    CHECK(!vofa_send(NULL, 1u) && !vofa_send(expected, SIZE_MAX / sizeof(float) + 1u));
    CHECK(submissions == before);
    CHECK(vofa_send(expected, 0u) && pendingLength == sizeof(tail));
    complete_segment();
    puts("PASS: all capture types/scales, whole blocks and application-owned release");
    puts("PASS: borrowed source, busy/rejection retries, tail phase and source reuse");
}

int main(void)
{
    CHECK(VOFA_BIG_ENDIAN == 0u && sizeof(float) == 4u);
    test_commands();
    test_capture_and_send();
    return 0;
}
