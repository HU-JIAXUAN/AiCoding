/* 宿主机测试：编码、可变参数发送、接收/命令、调参表。只需链接 vofa.c。 */
#include "vofa_cfg.h"

#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define CHECK(cond)                                                                                \
    do                                                                                             \
    {                                                                                              \
        if (!(cond))                                                                               \
        {                                                                                          \
            printf("CHECK failed at line %d: %s\n", __LINE__, #cond);                              \
            return 1;                                                                              \
        }                                                                                          \
    } while (0)

/* 本测试自带一个小配置 + 调参表，独立于 vofa_cfg.c。 */
typedef struct
{
    float kp;
    float ki;
} test_pid_t;
typedef struct
{
    test_pid_t pos;
    test_pid_t vel;
} test_cfg_t;

typedef struct
{
    test_cfg_t cfg;
    vofa_byte_t txFrame[VOFA_SINGLE_CHANNEL_FRAME_BYTES];
    uint32_t txLength;
} test_context_t;

static uint32_t g_uartTxCount;
static uint32_t g_uartTxLength;

void uart_tx_send(const vofa_byte_t *data, uint32_t length)
{
    (void)data;
    ++g_uartTxCount;
    g_uartTxLength = length;
}

int Serial_ReadByte(uint16_t *out)
{
    (void)out;
    return 0;
}

static void test_write(void *user, const vofa_byte_t *data, uint32_t length)
{
    test_context_t *ctx = (test_context_t *)user;
    uint32_t i;
    ctx->txLength = length;
    for (i = 0U; (i < length) && (i < VOFA_SINGLE_CHANNEL_FRAME_BYTES); ++i)
    {
        ctx->txFrame[i] = data[i];
    }
}

static void test_apply(void *user, const vofa_command_t *cmd)
{
    test_context_t *ctx = (test_context_t *)user;
    if (Vofa_CommandApplyFloat(cmd, "pos_kp", &ctx->cfg.pos.kp))
    {
        return;
    }
    if (Vofa_CommandApplyFloat(cmd, "pos_ki", &ctx->cfg.pos.ki))
    {
        return;
    }
    (void)Vofa_CommandApplyFloat(cmd, "vel_kp", &ctx->cfg.vel.kp);
}

static int check_encoding(void)
{
    static const vofa_byte_t expected[] = {0x00U, 0x00U, 0x00U, 0x00U, 0x00U, 0x00U, 0x80U,
                                           0x3FU, 0x00U, 0x00U, 0x80U, 0xBFU, 0x00U, 0x00U,
                                           0x80U, 0x7FU, 0x00U, 0x00U, 0x80U, 0x7FU};
    float values[] = {0.0F, 1.0F, -1.0F, INFINITY};
    vofa_byte_t frame[sizeof(expected) / sizeof(expected[0])];
    size_t n, i;

    memset(frame, 0xA5, sizeof(frame));
    n = Vofa_EncodeChannels(values, 4U, frame, sizeof(frame) / sizeof(frame[0]));
    CHECK((sizeof(expected) / sizeof(expected[0])) == n);
    for (i = 0U; i < n; ++i)
    {
        CHECK((frame[i] & 0xFFU) == (expected[i] & 0xFFU));
    }
    /* 参数保护 */
    CHECK(0U == Vofa_EncodeChannels(NULL, 1U, frame, 20U));
    CHECK(0U == Vofa_EncodeChannels(values, 1U, frame, 7U));
    return 0;
}

static int check_app_mode(void)
{
    app_config_t config = {0};

    g_uartTxCount = 0U;
    g_uartTxLength = 0U;
    Vofa_CfgInit(&config);

#if defined(VOFA_TEST_VERIFY_MODE)
    CHECK(VOFA_ERROR_NOT_INITIALIZED == Vofa_SendFloats(3U, 1.0, 2.0, 3.0));
    CHECK(0U == g_uartTxCount);
    Vofa_CfgProcess();
    CHECK(1U == g_uartTxCount);
    CHECK(16U == g_uartTxLength);
#else
    CHECK(VOFA_OK == Vofa_SendFloats(3U, 1.0, 2.0, 3.0));
    CHECK(1U == g_uartTxCount);
    CHECK(16U == g_uartTxLength);
#endif

    return 0;
}

int main(void)
{
    static const vofa_byte_t oneChannelFrame[VOFA_SINGLE_CHANNEL_FRAME_BYTES] = {
        0x00U, 0x00U, 0x80U, 0x3FU, 0x00U, 0x00U, 0x80U, 0x7FU};
    static const vofa_byte_t twoCommands[] = "pos_kp:12.5\nvel_kp+2\n";
    static const vofa_byte_t idleFrame[] = "pos_ki:0.25";
    static const vofa_byte_t addAgain[] = "pos_kp+=0.5\n";
    static const vofa_byte_t invalidFrame[] = "pos_kp:not-a-number";
    test_context_t context;
    float channel = 1.0F;
    size_t i;

    if (check_encoding() != 0)
    {
        return 1;
    }

    memset(&context, 0, sizeof(context));
    Vofa_Init(test_write, test_apply, &context);

    /* 数组发送与 VOFA_SEND 宏结果一致 */
    CHECK(VOFA_OK == Vofa_SendChannels(&channel, 1U));
    CHECK(sizeof(oneChannelFrame) == context.txLength);
    CHECK(0 == memcmp(oneChannelFrame, context.txFrame, sizeof(oneChannelFrame)));

    context.txLength = 0U;
    CHECK(VOFA_OK == VOFA_SEND(1.0F));
    CHECK(sizeof(oneChannelFrame) == context.txLength);
    CHECK(0 == memcmp(oneChannelFrame, context.txFrame, sizeof(oneChannelFrame)));

    CHECK(VOFA_ERROR_INVALID_ARGUMENT == Vofa_SendFloats(0U));
    CHECK(VOFA_ERROR_INVALID_ARGUMENT == Vofa_SendFloats(VOFA_MAX_CHANNELS + 1U));

    /* 命令按换行入队，Vofa_Process() 才应用 */
    CHECK(VOFA_OK == Vofa_RxFeed(twoCommands, sizeof(twoCommands) - 1U));
    CHECK(0.0F == context.cfg.pos.kp);
    Vofa_Process();
    CHECK(fabsf(context.cfg.pos.kp - 12.5F) < 0.0001F);
    CHECK(fabsf(context.cfg.vel.kp - 2.0F) < 0.0001F);

    /* IDLE 整帧（无换行） */
    CHECK(VOFA_OK == Vofa_RxFrame(idleFrame, sizeof(idleFrame) - 1U));
    Vofa_Process();
    CHECK(fabsf(context.cfg.pos.ki - 0.25F) < 0.0001F);

    /* 增量 */
    CHECK(VOFA_OK == Vofa_RxFeed(addAgain, sizeof(addAgain) - 1U));
    Vofa_Process();
    CHECK(fabsf(context.cfg.pos.kp - 13.0F) < 0.0001F);

    /* 非法数值被拒绝，不改任何东西 */
    CHECK(VOFA_ERROR_FRAME_INVALID == Vofa_RxFrame(invalidFrame, sizeof(invalidFrame) - 1U));
    Vofa_Process();
    CHECK(fabsf(context.cfg.pos.kp - 13.0F) < 0.0001F);

    /* 队列满会上报 */
    for (i = 0U; i < VOFA_COMMAND_QUEUE_DEPTH; ++i)
    {
        CHECK(VOFA_OK == Vofa_RxFeed(addAgain, sizeof(addAgain) - 1U));
    }
    CHECK(VOFA_ERROR_QUEUE_FULL == Vofa_RxFeed(addAgain, sizeof(addAgain) - 1U));
    Vofa_Process();

    if (check_app_mode() != 0)
    {
        return 1;
    }

    puts("test_vofa: PASS");
    return 0;
}
