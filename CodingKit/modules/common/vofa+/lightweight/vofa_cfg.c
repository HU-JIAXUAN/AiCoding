/**
 * @file  vofa_cfg.c
 * @brief VOFA 适配层示例：接串口 + 调参表 + 验证模式波形。
 * @version 1.0.0
 *
 * 复制本文件到你的工程，改 [1][2][3] 三处。
 */

#include "vofa_cfg.h"

#include <stddef.h>

/* User Include Start */

/* User Include End */

/* User Cfg Start */
/* [1] 串口发送：换成你的发送函数。C2000 用循环发低 8 位（见文件末尾）。 */
extern void uart_tx_send(const vofa_byte_t *data, uint32_t length);
#define VOFA_SERIAL_SEND(data, length) uart_tx_send((data), (length))

/* [2] 调参表：一个可调变量一行。命令：name:val 赋值 / name+val / name+=val 增量。 */
typedef struct
{
    const char *name;
    size_t offset;
} vofa_binding_t;
#define VOFA_BIND(name, member)                                                                    \
    {                                                                                              \
        (name), offsetof(app_config_t, member)                                                     \
    }

static const vofa_binding_t k_bindings[] = {
    VOFA_BIND("pos_kp", pos_pid.kp), VOFA_BIND("pos_ki", pos_pid.ki),
    VOFA_BIND("pos_kd", pos_pid.kd), VOFA_BIND("vel_kp", vel_pid.kp),
    VOFA_BIND("vel_ki", vel_pid.ki), VOFA_BIND("vel_kd", vel_pid.kd),
    VOFA_BIND("cur_kp", cur_pid.kp), VOFA_BIND("cur_ki", cur_pid.ki),
    VOFA_BIND("cur_kd", cur_pid.kd),
};
#define VOFA_BINDING_COUNT (sizeof(k_bindings) / sizeof(k_bindings[0]))

/* [3] 模式开关：标准 / 验证，全部在这一段（外部不做判断）。
 *     改下面默认值，或编译时 -DVOFA_APP_MODE=VOFA_APP_MODE_VERIFY。
 *     验证模式：还没接真实数据时，发 3 路 120° 正弦自检 JustFloat 链路。 */
#define VOFA_APP_MODE_STANDARD 0
#define VOFA_APP_MODE_VERIFY 1
#ifndef VOFA_APP_MODE
#define VOFA_APP_MODE VOFA_APP_MODE_STANDARD
#endif

#if (VOFA_APP_MODE == VOFA_APP_MODE_VERIFY)
#include <math.h>
#ifndef VOFA_PI
#define VOFA_PI 3.14159265358979F
#endif
/* 发 3 路相位差 120° 的正弦波（仅验证模式）。精确定频就用定时器调 Vofa_CfgProcess()。 */
static void vofa_cfg_send_waveform(void)
{
    static float t = 0.0F;
    const float ts = 0.01F;     /* 正弦周期(s) */
    const float amp = 16.0F;    /* 幅值 */
    const float Ts = 0.000001F; /* 每次步进(s)，每周期 10000 点 */
    const float w = 2.0F * VOFA_PI / ts;
    const float channels[] = {amp * sinf(w * t), amp * sinf(w * t - 2.0F * VOFA_PI / 3.0F),
                              amp * sinf(w * t + 2.0F * VOFA_PI / 3.0F)};
    vofa_byte_t frame[(3U * VOFA_FLOAT_BYTES) + VOFA_TAIL_BYTES];
    size_t frameLength;

    /* 验证帧绕过被禁用的业务发送回调，只经 cfg 串口适配点发出。 */
    frameLength = Vofa_EncodeChannels(channels, 3U, frame, sizeof(frame) / sizeof(frame[0]));
    if (frameLength != 0U)
    {
        VOFA_SERIAL_SEND(frame, (uint32_t)frameLength);
    }
    t += Ts;
    if (t >= ts)
    {
        t -= ts;
    }
}
#endif

/* User Cfg End */

#if (VOFA_APP_MODE == VOFA_APP_MODE_STANDARD)
/* 发送回调：整帧交给串口（走哪个口由 [1] 决定）。 */
static void vofa_cfg_write(void *context, const vofa_byte_t *data, uint32_t length)
{
    (void)context;
    VOFA_SERIAL_SEND(data, length);
}
#endif

/* 调参回调：命令名匹配表里哪行，就写对应偏移处的 float。 */
static void vofa_cfg_apply(void *context, const vofa_command_t *command)
{
    unsigned char *base = (unsigned char *)context;
    size_t index;

    if ((base == NULL) || (command == NULL))
    {
        return;
    }
    for (index = 0U; index < VOFA_BINDING_COUNT; ++index)
    {
        float *target = (float *)(void *)(base + k_bindings[index].offset);
        if (Vofa_CommandApplyFloat(command, k_bindings[index].name, target))
        {
            return;
        }
    }
}

void Vofa_CfgInit(app_config_t *config)
{
#if (VOFA_APP_MODE == VOFA_APP_MODE_VERIFY)
    /* 不注册业务发送回调，统一拒绝外部 VOFA 发送入口。 */
    Vofa_Init(NULL, vofa_cfg_apply, config);
#else
    Vofa_Init(vofa_cfg_write, vofa_cfg_apply, config);
#endif
}

/* [2b] 串口接收：读到一字节返回 1。DMA 整帧接收则改用 Vofa_RxFrame。 */
extern int Serial_ReadByte(uint16_t *out);

/* 主循环服务。标准：收帧 + 调参；验证：只发正弦波（在本函数内部判断）。 */
void Vofa_CfgProcess(void)
{
#if (VOFA_APP_MODE == VOFA_APP_MODE_VERIFY)
    vofa_cfg_send_waveform();
#else
    uint16_t raw;

    /* 逐字节喂核心，核心按换行组帧。 */
    while (Serial_ReadByte(&raw) != 0)
    {
        vofa_byte_t octet = (vofa_byte_t)(raw & 0xFFU);
        (void)Vofa_RxFeed(&octet, 1U);
    }
    Vofa_Process();
#endif
}

/* clang-format off */
/* C2000/C28x 的 [1]：发每个元素低 8 位；并发时用 DINT/EINT 定义临界区。
 *   extern void Sci_SendByte(uint16_t);
 *   #define VOFA_SERIAL_SEND(d,n) \
 *       do { uint32_t i_; for (i_=0;i_<(n);++i_) Sci_SendByte((uint16_t)((d)[i_]&0xFFU)); } while (0)
 *   #define VOFA_ENTER_CRITICAL()  __asm(" DINT")
 *   #define VOFA_EXIT_CRITICAL()   __asm(" EINT")
 */
/* clang-format on */
