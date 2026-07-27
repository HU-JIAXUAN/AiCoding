/**
 * @file    vofa.h
 * @brief   轻量、可移植的 VOFA+ JustFloat 波形/命令协议核心。
 * @author  HU JIAXUAN
 * @date    2026-07-24
 * @version 1.0.0
 *
 * @details
 * 设计目标：
 *   - 可移植：不依赖 UART/DMA/FSP/HAL，只通过两个注入的回调（发送整帧、应用命令）
 *     与平台打交道。
 *   - 一份源码双平台：8 位 char 的 MCU（RZ/T2M、Cortex）与 16 位 char 的 DSP
 *     （TI C2000/C28x）都能直接编译。
 *   - 好上手：一次初始化；三种发送方式（数组 / 可变参数 / 宏）；换行或 IDLE 判帧
 *     两种接收入口；命令在主循环里统一执行。
 *
 * 最小用法：
 *   1. 写一个“把 octet 发给串口”的发送回调；
 *   2.（可选）写一个应用调参命令的回调；
 *   3. Vofa_Init(write, command_or_null, context);
 *   4. 发送：VOFA_SEND(a, b, c);  或  Vofa_SendFloats(3U, a, b, c);
 *   5. 喂接收：Vofa_RxFeed(字节流) 或 Vofa_RxFrame(整帧);
 *   6. 主循环调用 Vofa_Process() 执行排队的命令。
 */

#ifndef VOFA_H
#define VOFA_H

#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

/* ============================== 字节宽度抽象 ============================== */
/*
 * 一个 vofa_byte_t 元素恰好承载一个协议 octet（0..255）。
 * 在 8 位 char 目标上它就是真正的字节；在 C2000（CHAR_BIT == 16）上它是 16 位字，
 * 低 8 位才是那个 octet —— 串口移植层只发每个元素的低字节。缺少 uint8_t 的编译器
 * （如 C28x）永远走不到 uint8_t 那条分支，所以两个平台都能编译。
 */
#if (CHAR_BIT == 8)
    typedef uint8_t vofa_byte_t;
#else
typedef uint16_t vofa_byte_t;
#endif

    /* ============================== 协议固定常量 ============================= */

#define VOFA_FLOAT_BYTES (4U)                /**< 每通道 float32 的 octet 数。   */
#define VOFA_TAIL_BYTES (4U)                 /**< JustFloat 固定帧尾 octet 数。  */
#define VOFA_SINGLE_CHANNEL_FRAME_BYTES (8U) /**< 单通道帧 = 一路 + 帧尾。       */

    /* ============================== 可裁剪上限 =============================== */

#ifndef VOFA_MAX_CHANNELS
#define VOFA_MAX_CHANNELS (16U) /**< 单帧最大通道数。               */
#endif

#ifndef VOFA_COMMAND_NAME_BYTES
#define VOFA_COMMAND_NAME_BYTES (32U) /**< 命令名缓冲（含结束符）。       */
#endif

#ifndef VOFA_COMMAND_QUEUE_DEPTH
#define VOFA_COMMAND_QUEUE_DEPTH (4U) /**< 命令队列深度。                 */
#endif

#ifndef VOFA_RX_FRAME_BYTES
#define VOFA_RX_FRAME_BYTES (48U) /**< 单条命令文本上限。             */
#endif

/* ================ 临界区（并发时在工程里覆盖它） ======================== */
/* C28x 示例： #define VOFA_ENTER_CRITICAL() __asm(" DINT") / EXIT __asm(" EINT") */
#ifndef VOFA_ENTER_CRITICAL
#define VOFA_ENTER_CRITICAL()                                                                      \
    do                                                                                             \
    {                                                                                              \
    } while (0)
#endif
#ifndef VOFA_EXIT_CRITICAL
#define VOFA_EXIT_CRITICAL()                                                                       \
    do                                                                                             \
    {                                                                                              \
    } while (0)
#endif

/* ============================== 配置检查 ================================ */
#if (VOFA_MAX_CHANNELS == 0U)
#error "VOFA_MAX_CHANNELS must be greater than zero."
#endif
#if (VOFA_COMMAND_NAME_BYTES < 2U)
#error "VOFA_COMMAND_NAME_BYTES must be at least two."
#endif
#if (VOFA_COMMAND_QUEUE_DEPTH == 0U)
#error "VOFA_COMMAND_QUEUE_DEPTH must be greater than zero."
#endif
#if (VOFA_RX_FRAME_BYTES < 4U)
#error "VOFA_RX_FRAME_BYTES is too small."
#endif

    /** @brief 公共接口返回值。 */
    typedef enum
    {
        VOFA_OK = 0,                      /**< 成功。                              */
        VOFA_ERROR_INVALID_ARGUMENT = -1, /**< 参数为空或越界。                    */
        VOFA_ERROR_NOT_INITIALIZED = -2,  /**< 模块或回调未初始化。                */
        VOFA_ERROR_BUFFER_TOO_SMALL = -3, /**< 输出缓冲区太小。                    */
        VOFA_ERROR_FRAME_INVALID = -4,    /**< 命令语法或数值非法。                */
        VOFA_ERROR_FRAME_TOO_LONG = -5,   /**< 命令文本超出上限。                  */
        VOFA_ERROR_QUEUE_FULL = -6        /**< 命令队列已满。                      */
    } vofa_result_t;

    /** @brief 命令对目标值执行的操作。 */
    typedef enum
    {
        VOFA_COMMAND_ADD = 0, /**< 在目标当前值上累加。                          */
        VOFA_COMMAND_ASSIGN   /**< 直接赋值给目标。                              */
    } vofa_command_operation_t;

    /** @brief 一条与平台无关的、已解析的调参命令。 */
    typedef struct
    {
        char name[VOFA_COMMAND_NAME_BYTES]; /**< 目标名，含义由应用决定。          */
        float value;                        /**< 赋值或增量的数值。                */
        vofa_command_operation_t operation; /**< 要执行的操作。                    */
    } vofa_command_t;

    /**
     * @brief 平台整帧发送回调。
     * @param context 由 Vofa_Init() 传入的用户上下文。
     * @param data    octet 缓冲区；每个元素承载一个 octet（DSP 上取低 8 位）。
     * @param length  帧长度（octet 数）。
     * @note 每帧只回调一次；不要在回调外保留 data 指针。
     */
    typedef void (*vofa_write_fn)(void *context, const vofa_byte_t *data, uint32_t length);

    /**
     * @brief 应用命令回调，由 Vofa_Process() 触发。
     * @param context 由 Vofa_Init() 传入的用户上下文。
     * @param command 已通过语法校验的命令。
     */
    typedef void (*vofa_command_fn)(void *context, const vofa_command_t *command);

    /** @brief 初始化模块并注册回调（两个回调都可为 NULL）。 */
    void Vofa_Init(vofa_write_fn write_fn, vofa_command_fn command_fn, void *context);

    /**
     * @brief 把若干通道编码为 VOFA+ JustFloat 小端帧。
     * @return 帧长度（octet 数）；参数非法或缓冲区过小时返回 0。
     */
    size_t Vofa_EncodeChannels(const float *channels, size_t channelCount, vofa_byte_t *frame,
                               size_t frameCapacity);

    /** @brief 编码并把整帧交给发送回调。 */
    vofa_result_t Vofa_SendChannels(const float *channels, size_t channelCount);

    /**
     * @brief 按可变参数发送若干通道（1..VOFA_MAX_CHANNELS）。
     * @note float 实参会自动提升为 double；整型实参必须由调用方显式转成 double。
     *       为避开这个陷阱，日常优先用 VOFA_SEND()。
     */
    vofa_result_t Vofa_SendFloats(size_t channelCount, ...);

    /** @brief 喂入以换行分隔的接收字节；凑齐一条命令即入队。 */
    vofa_result_t Vofa_RxFeed(const vofa_byte_t *data, size_t length);

    /** @brief 解析一整帧命令（如 UART IDLE/DMA 判出的整帧）。 */
    vofa_result_t Vofa_RxFrame(const vofa_byte_t *frame, size_t length);

    /** @brief 主循环里排空命令队列，逐条调用命令回调。 */
    void Vofa_Process(void);

    /**
     * @brief 把一条命令应用到某个具名 float 目标。
     * @return 名字匹配返回 true（数值非有限时保持目标不变，但仍返回 true）。
     */
    bool Vofa_CommandApplyFloat(const vofa_command_t *command, const char *name, float *target);

/**
 * @brief 自动数个数、自动转 float 的发送宏。
 *
 * 一次消掉可变参数的两个坑：不用手写通道数；每个实参都被复合字面量强制转成
 * float（整型实参会得到编译告警，而不是通过 va_arg 读到垃圾）。
 *
 * 例：VOFA_SEND(position, (float)raw_count, adc0);
 */
#define VOFA_SEND(...)                                                                             \
    Vofa_SendChannels((const float[]){__VA_ARGS__},                                                \
                      (size_t)(sizeof((const float[]){__VA_ARGS__}) / sizeof(float)))

#ifdef __cplusplus
}
#endif

#endif /* VOFA_H */
