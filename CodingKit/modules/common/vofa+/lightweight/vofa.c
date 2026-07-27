/**
 * @file    vofa.c
 * @brief   轻量、可移植的 VOFA+ JustFloat 协议核心实现。
 * @author  HU JIAXUAN
 * @date    2026-07-24
 * @version 1.0.0
 *
 * 不含任何平台头文件；设计说明见 vofa.h。
 */

#include "vofa.h"

#include <ctype.h>
#include <float.h>
#include <math.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

/* JustFloat 要求 float 为 IEEE-754 binary32，且 uint32_t 为 32 位。 */
typedef char vofa_float_is_32_bits[((sizeof(float) * CHAR_BIT) == 32) ? 1 : -1];
typedef char vofa_u32_is_32_bits[((sizeof(uint32_t) * CHAR_BIT) == 32) ? 1 : -1];
#if (FLT_RADIX != 2) || (FLT_MANT_DIG != 24) || (FLT_MAX_EXP != 128)
#error "VOFA+ JustFloat requires IEEE-754 binary32 float format."
#endif

typedef struct
{
    vofa_write_fn write;
    vofa_command_fn command;
    void *context;
    bool initialized;

    /* 静态发送/接收缓冲区，全程不使用动态内存。 */
    vofa_byte_t txFrame[(VOFA_MAX_CHANNELS * VOFA_FLOAT_BYTES) + VOFA_TAIL_BYTES];
    char rxFrame[VOFA_RX_FRAME_BYTES + 1U];
    size_t rxLength;
    bool rxDiscarding;

    /* 接收只负责入队；Vofa_Process() 才出队并应用。 */
    vofa_command_t commandQueue[VOFA_COMMAND_QUEUE_DEPTH];
    size_t queueHead;
    size_t queueTail;
    size_t queueCount;
} vofa_state_t;

static vofa_state_t g_vofa;

/* JustFloat 固定帧尾：0x00 0x00 0x80 0x7F。 */
static const vofa_byte_t g_justFloatTail[VOFA_TAIL_BYTES] = {0x00U, 0x00U, 0x80U, 0x7FU};

/** @brief 判断 ASCII 空白字符。 */
static bool vofa_is_space(char c)
{
    return (0 != isspace((unsigned char)c));
}

/** @brief 把一个 float32 序列化为固定小端的 4 个 octet（与 CPU 端序无关）。 */
static void vofa_encode_float(float value, vofa_byte_t out[VOFA_FLOAT_BYTES])
{
    uint32_t bits;

    /* 先取位表示，再按位移拆出各 octet，因此大端/小端 CPU 输出一致。 */
    memcpy(&bits, &value, sizeof(bits));
    out[0] = (vofa_byte_t)(bits & 0xFFU);
    out[1] = (vofa_byte_t)((bits >> 8U) & 0xFFU);
    out[2] = (vofa_byte_t)((bits >> 16U) & 0xFFU);
    out[3] = (vofa_byte_t)((bits >> 24U) & 0xFFU);
}

/** @brief 把一条命令压入固定深度环形队列。 */
static vofa_result_t vofa_queue_push(const vofa_command_t *command)
{
    vofa_result_t result = VOFA_OK;

    /* 生产者（接收）与消费者（主循环）可能在不同上下文，用临界区护住计数与索引。 */
    VOFA_ENTER_CRITICAL();
    if (g_vofa.queueCount >= VOFA_COMMAND_QUEUE_DEPTH)
    {
        result = VOFA_ERROR_QUEUE_FULL;
    }
    else
    {
        g_vofa.commandQueue[g_vofa.queueHead] = *command;
        g_vofa.queueHead = (g_vofa.queueHead + 1U) % VOFA_COMMAND_QUEUE_DEPTH;
        ++g_vofa.queueCount;
    }
    VOFA_EXIT_CRITICAL();

    return result;
}

/** @brief 从环形队列取出一条命令。 */
static bool vofa_queue_pop(vofa_command_t *command)
{
    bool available = false;

    VOFA_ENTER_CRITICAL();
    if ((command != NULL) && (g_vofa.queueCount > 0U))
    {
        *command = g_vofa.commandQueue[g_vofa.queueTail];
        g_vofa.queueTail = (g_vofa.queueTail + 1U) % VOFA_COMMAND_QUEUE_DEPTH;
        --g_vofa.queueCount;
        available = true;
    }
    VOFA_EXIT_CRITICAL();

    return available;
}

/*
 * 把 "name:value"（赋值）、"name+value" 或 "name+=value"（增量）解析成一条命令。
 * 会裁掉首尾空白，并校验数值是有限的。
 */
static vofa_result_t vofa_parse_command(const char *frame, size_t length, vofa_command_t *command)
{
    char localFrame[VOFA_RX_FRAME_BYTES + 1U];
    char *operatorPosition;
    char *valueStart;
    char *valueEnd;
    char *nameStart;
    char *nameEnd;
    size_t nameLength;
    double parsed;

    if ((frame == NULL) || (length == 0U) || (command == NULL))
    {
        return VOFA_ERROR_INVALID_ARGUMENT;
    }

    /* DMA/IDLE 帧常带 CR/LF，先裁掉尾部空白，再复制成以 '\0' 结尾的本地串。 */
    while ((length > 0U) && vofa_is_space(frame[length - 1U]))
    {
        --length;
    }
    if ((length == 0U) || (length > VOFA_RX_FRAME_BYTES))
    {
        return VOFA_ERROR_FRAME_INVALID;
    }

    memcpy(localFrame, frame, length);
    localFrame[length] = '\0';

    /* 跳过名字前的空白：':' 表示赋值，'+' 表示在当前值上增量。 */
    nameStart = localFrame;
    while (vofa_is_space(*nameStart))
    {
        ++nameStart;
    }

    operatorPosition = strchr(nameStart, ':');
    if (operatorPosition != NULL)
    {
        command->operation = VOFA_COMMAND_ASSIGN;
    }
    else
    {
        operatorPosition = strchr(nameStart, '+');
        if (operatorPosition == NULL)
        {
            return VOFA_ERROR_FRAME_INVALID;
        }
        command->operation = VOFA_COMMAND_ADD;
    }

    /* 裁掉运算符前的空白，得到名字并检查长度。 */
    nameEnd = operatorPosition;
    while ((nameEnd > nameStart) && vofa_is_space(nameEnd[-1]))
    {
        --nameEnd;
    }
    nameLength = (size_t)(nameEnd - nameStart);
    if ((nameLength == 0U) || (nameLength >= VOFA_COMMAND_NAME_BYTES))
    {
        return VOFA_ERROR_FRAME_INVALID;
    }

    /* 同时兼容 "name+value" 和更直观的 "name+=value"。 */
    valueStart = operatorPosition + 1;
    if ((command->operation == VOFA_COMMAND_ADD) && (*valueStart == '='))
    {
        ++valueStart;
    }
    while (vofa_is_space(*valueStart))
    {
        ++valueStart;
    }
    if (*valueStart == '\0')
    {
        return VOFA_ERROR_FRAME_INVALID;
    }

    /* strtod 是 C89 就有的函数，IAR 与 TI RTS 都提供，比 strtof 更通用。 */
    parsed = strtod(valueStart, &valueEnd);
    command->value = (float)parsed;
    if ((valueEnd == valueStart) || !isfinite(command->value))
    {
        return VOFA_ERROR_FRAME_INVALID;
    }
    while (vofa_is_space(*valueEnd))
    {
        ++valueEnd;
    }
    if (*valueEnd != '\0')
    {
        return VOFA_ERROR_FRAME_INVALID;
    }

    memcpy(command->name, nameStart, nameLength);
    command->name[nameLength] = '\0';

    return VOFA_OK;
}

/** @brief 清空内部状态，注册平台发送/应用命令回调。 */
void Vofa_Init(vofa_write_fn write_fn, vofa_command_fn command_fn, void *context)
{
    /* 每次初始化都清空发送帧、接收缓冲和队列，避免复位后残留脏数据。 */
    memset(&g_vofa, 0, sizeof(g_vofa));
    g_vofa.write = write_fn;
    g_vofa.command = command_fn;
    g_vofa.context = context;
    g_vofa.initialized = true;
}

/** @brief 把若干通道编码为固定小端的 JustFloat 帧。 */
size_t Vofa_EncodeChannels(const float *channels, size_t channelCount, vofa_byte_t *frame,
                           size_t frameCapacity)
{
    size_t channelIndex;
    size_t frameLength;

    /* 校验输出缓冲、通道指针，并防止 size_t 乘法溢出/越界。 */
    if ((frame == NULL) || ((channels == NULL) && (channelCount != 0U)) ||
        (frameCapacity < VOFA_TAIL_BYTES) ||
        (channelCount > ((frameCapacity - VOFA_TAIL_BYTES) / VOFA_FLOAT_BYTES)))
    {
        return 0U;
    }

    frameLength = (channelCount * VOFA_FLOAT_BYTES) + VOFA_TAIL_BYTES;
    for (channelIndex = 0U; channelIndex < channelCount; ++channelIndex)
    {
        vofa_encode_float(channels[channelIndex], &frame[channelIndex * VOFA_FLOAT_BYTES]);
    }
    /* 帧尾与通道数无关，始终追加固定 4 字节。 */
    memcpy(&frame[frameLength - VOFA_TAIL_BYTES], g_justFloatTail, sizeof(g_justFloatTail));

    return frameLength;
}

/** @brief 编码通道并把整帧一次性交给平台发送回调。 */
vofa_result_t Vofa_SendChannels(const float *channels, size_t channelCount)
{
    size_t frameLength;

    /* 只有注册了发送回调才可发送。 */
    if (!g_vofa.initialized || (g_vofa.write == NULL))
    {
        return VOFA_ERROR_NOT_INITIALIZED;
    }
    if ((channels == NULL) || (channelCount == 0U) || (channelCount > VOFA_MAX_CHANNELS))
    {
        return VOFA_ERROR_INVALID_ARGUMENT;
    }

    frameLength =
        Vofa_EncodeChannels(channels, channelCount, g_vofa.txFrame, sizeof(g_vofa.txFrame));
    if (frameLength == 0U)
    {
        return VOFA_ERROR_BUFFER_TOO_SMALL;
    }

    /* 只回调一次，把整帧交出去，DMA 的分帧边界由平台层保证。 */
    g_vofa.write(g_vofa.context, g_vofa.txFrame, (uint32_t)frameLength);
    return VOFA_OK;
}

/** @brief 按可变参数顺序发送若干 JustFloat 通道。 */
vofa_result_t Vofa_SendFloats(size_t channelCount, ...)
{
    float channels[VOFA_MAX_CHANNELS];
    va_list arguments;
    size_t channelIndex;

    if ((channelCount == 0U) || (channelCount > VOFA_MAX_CHANNELS))
    {
        return VOFA_ERROR_INVALID_ARGUMENT;
    }

    /* float 经过 '...' 会被提升为 double：按 double 取出，再收窄回 float。 */
    va_start(arguments, channelCount);
    for (channelIndex = 0U; channelIndex < channelCount; ++channelIndex)
    {
        channels[channelIndex] = (float)va_arg(arguments, double);
    }
    va_end(arguments);

    return Vofa_SendChannels(channels, channelCount);
}

/** @brief 喂入以换行分隔的接收字节流，凑齐一条命令即解析入队。 */
vofa_result_t Vofa_RxFeed(const vofa_byte_t *data, size_t length)
{
    size_t index;
    vofa_result_t result = VOFA_OK;

    if (!g_vofa.initialized)
    {
        return VOFA_ERROR_NOT_INITIALIZED;
    }
    if ((data == NULL) && (length != 0U))
    {
        return VOFA_ERROR_INVALID_ARGUMENT;
    }

    for (index = 0U; index < length; ++index)
    {
        /* 取低 8 位：DSP 上 char 是 16 位，这样两平台解析到同样的字节。 */
        char character = (char)(data[index] & 0xFFU);

        /* 换行确定命令边界；成功即入队，绝不在接收路径里直接改应用参数。 */
        if (character == '\n')
        {
            if (g_vofa.rxDiscarding)
            {
                result = VOFA_ERROR_FRAME_TOO_LONG;
            }
            else if (g_vofa.rxLength > 0U)
            {
                vofa_command_t command;
                vofa_result_t frameResult =
                    vofa_parse_command(g_vofa.rxFrame, g_vofa.rxLength, &command);

                if (frameResult == VOFA_OK)
                {
                    frameResult = vofa_queue_push(&command);
                }
                if (frameResult != VOFA_OK)
                {
                    result = frameResult;
                }
            }
            else
            {
                /* 空行，直接忽略。 */
            }
            g_vofa.rxLength = 0U;
            g_vofa.rxDiscarding = false;
        }
        else if (!g_vofa.rxDiscarding)
        {
            /* 命令超过固定缓冲：截断并进入丢弃态，直到下一个换行。 */
            if (g_vofa.rxLength >= VOFA_RX_FRAME_BYTES)
            {
                g_vofa.rxLength = 0U;
                g_vofa.rxDiscarding = true;
                result = VOFA_ERROR_FRAME_TOO_LONG;
            }
            else
            {
                g_vofa.rxFrame[g_vofa.rxLength] = character;
                ++g_vofa.rxLength;
            }
        }
        else
        {
            /* 超长帧丢弃中：忽略字符，等下一个换行。 */
        }
    }

    return result;
}

/** @brief 解析一整帧命令（平台已判好边界，如 UART IDLE 帧）。 */
vofa_result_t Vofa_RxFrame(const vofa_byte_t *frame, size_t length)
{
    char localFrame[VOFA_RX_FRAME_BYTES + 1U];
    vofa_command_t command;
    vofa_result_t result;
    size_t index;

    if (!g_vofa.initialized)
    {
        return VOFA_ERROR_NOT_INITIALIZED;
    }
    if ((frame == NULL) || (length == 0U))
    {
        return VOFA_ERROR_INVALID_ARGUMENT;
    }
    if (length > VOFA_RX_FRAME_BYTES)
    {
        return VOFA_ERROR_FRAME_TOO_LONG;
    }

    /* 逐个取低 8 位，使 16 位 char 的 DSP 也解析到相同的字节序列。 */
    for (index = 0U; index < length; ++index)
    {
        localFrame[index] = (char)(frame[index] & 0xFFU);
    }

    result = vofa_parse_command(localFrame, length, &command);
    if (result == VOFA_OK)
    {
        result = vofa_queue_push(&command);
    }

    return result;
}

/** @brief 在主循环里排空命令队列，逐条触发应用回调。 */
void Vofa_Process(void)
{
    vofa_command_t command;

    if (!g_vofa.initialized)
    {
        return;
    }

    /* 应用回调只在这里触发；中断/DMA 回调不会走到这里，因此不会直接改控制参数。 */
    while (vofa_queue_pop(&command))
    {
        if (g_vofa.command != NULL)
        {
            g_vofa.command(g_vofa.context, &command);
        }
    }
}

/** @brief 通用助手：把一条命令应用到某个具名 float 目标。 */
bool Vofa_CommandApplyFloat(const vofa_command_t *command, const char *name, float *target)
{
    float nextValue;

    /* 名字精确匹配才处理；未匹配直接返回 false，不碰目标。 */
    if ((command == NULL) || (name == NULL) || (target == NULL) ||
        (0 != strcmp(command->name, name)))
    {
        return false;
    }

    if (command->operation == VOFA_COMMAND_ASSIGN)
    {
        nextValue = command->value;
    }
    else
    {
        nextValue = *target + command->value;
    }

    /* 增量后若变成 Inf/NaN，则拒绝写入，保持目标原值。 */
    if (isfinite(nextValue))
    {
        *target = nextValue;
    }

    return true;
}
