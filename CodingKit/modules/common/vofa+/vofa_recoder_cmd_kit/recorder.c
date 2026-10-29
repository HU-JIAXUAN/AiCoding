/**
 * @file    recorder.c
 * @brief   按地址表采集工程量并维护数据缓冲
 * @details 信号表由工程业务区提供；单一 ISR 按类型读取并换算，按完整组发布
 *          采集节拍由调用方管理；主循环使用完该块后归还缓冲
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#include "recorder.h"

#include <stdint.h>
#include <math.h>

/* 约束编译器的共享访问顺序，不改变中断状态或生成 CPU 屏障 */
#define RECORDER_BARRIER() __atomic_signal_fence(__ATOMIC_ACQ_REL)

/* 每个采集数组的 float 容量 */
#define RECORDER_BUFFER_SIZE (256u)

/* 双缓冲数据保存区 */
static float bufferA[RECORDER_BUFFER_SIZE];
static float bufferB[RECORDER_BUFFER_SIZE];

RecorderBlock g_recorderBlocks[2] = {
    {bufferA, sizeof(bufferA) / sizeof(bufferA[0]), false}, /* 第 0 项：addr 保存 A 数组首地址 */
    {bufferB, sizeof(bufferB) / sizeof(bufferB[0]), false}, /* 第 1 项：addr 保存 B 数组首地址 */
};

static unsigned writeBlock;
static size_t writeOffset;

/************************ 数据采集 ************************/
/* 按地址表采集一组数据，分频由调用方管理 */
void recorder(void)
{
    RecorderBlock *block = &g_recorderBlocks[writeBlock];
    float *buffer = (writeBlock == 0u) ? bufferA : bufferB;
    const size_t channelCount = mDecodePtrCount;
    size_t channel;

    if (block->ready || (channelCount > RECORDER_BUFFER_SIZE)) {
        return;
    }
    RECORDER_BARRIER();
    for (channel = 0u; channel < channelCount; channel++) {
        const RecorderSignal *signal = &mDecodePtrTbl[channel];
        const volatile void *address = signal->address;
        float value;

        switch (signal->type) {
            case RS_U8:
                value = (float)*(const volatile uint8_t *)address;
                break;
            case RS_U16:
                value = (float)*(const volatile uint16_t *)address;
                break;
            case RS_I16:
                value = (float)*(const volatile int16_t *)address;
                break;
            case RS_I32:
                value = (float)*(const volatile int32_t *)address;
                break;
            case RS_U32: {
                uint32_t raw;
                const volatile unsigned char *source = address;
                unsigned char *destination = (unsigned char *)&raw;
                size_t byte;

                /* 按对象字节读取，兼容不同 32 位无符号 C 类型 */
                for (byte = 0u; byte < sizeof(raw); byte++) {
                    destination[byte] = source[byte];
                }
                value = (float)raw;
                break;
            }
            case RS_I64:
                value = (float)*(const volatile int64_t *)address;
                break;
            case RS_FLOAT:
                value = *(const volatile float *)address;
                break;
            default:
                value = NAN;
                break;
        }
        buffer[writeOffset + channel] = value * signal->scale;
    }

    writeOffset += channelCount;
    /* 剩余空间放不下下一完整组时，发布本块有效数据 */
    if (writeOffset + channelCount > RECORDER_BUFFER_SIZE) {
        block->count = writeOffset;
        RECORDER_BARRIER();
        block->ready = true;
        writeOffset = 0u;
        writeBlock ^= 1u;
    }
}
