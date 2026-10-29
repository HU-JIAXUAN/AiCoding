/**
 * @file    vofa.c
 * @brief   JustFloat 组帧发送与完整帧初步解析
 * @details 同步拆分调用方提供的完整可写帧，不读取串口、不维护接收或业务状态
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#include "vofa.h"
#include <string.h>

typedef char VofaFloat32[(sizeof(float) == 4u) ? 1 : -1];

#if VOFA_BIG_ENDIAN
/* 大端：每次换序一个 float，两槽共 8 字节 */
static uint32_t convertedWords[2]; /* 一个供发送接口读取，另一个准备下个值 */
static size_t sentValues;          /* 本帧已被发送接口接受的 float 数 */
#else
/* 只记录下一段是帧尾；前一段是否释放由发送接口判断 */
static bool tailPending;
#endif

static char *trim_space(char *text, char *end);

/* 去除一段文本两端的 ASCII 空格和 TAB */
static char *trim_space(char *text, char *end)
{
    while ((text < end) && ((*text == ' ') || (*text == '\t'))) {
        text++;
    }
    while ((end > text) && ((end[-1] == ' ') || (end[-1] == '\t'))) {
        end--;
    }
    *end = '\0';
    return text;
}

/* 拆分完整帧并同步提交 */
void vofa_parse(char *frame, size_t length)
{
    char *separator = memchr(frame, ':', length);
    char *name;
    char *valueText;

    if (separator == NULL) {
        return;
    }
    *separator = '\0';
    name = trim_space(frame, separator);
    valueText = trim_space(separator + 1, frame + length);
    (void)VOFA_COMMAND(name, valueText);
}

/* 主循环以同一组数据重试；发送接口释放数据段后再提交帧尾 */
bool vofa_send(const float *values, size_t count)
{
    /* 固定字节顺序，uint32_t 成员保证帧尾按四字节对齐 */
    static const union {
        uint32_t alignment;
        uint8_t bytes[4];
    } frameTail = {.bytes = {0x00u, 0x00u, 0x80u, 0x7fu}};

    if ((values == NULL) || (count > SIZE_MAX / sizeof(*values))) {
        return false;
    }
#if VOFA_BIG_ENDIAN
    while (sentValues < count) {
        /* 已提交数值的奇偶决定空闲槽，另一槽可能仍在使用 */
        uint8_t *word = (uint8_t *)&convertedWords[sentValues & 1u];
        size_t byte;

        for (byte = 0u; byte < sizeof(float); byte++) {
            word[byte] = VOFA_FLOAT_BYTE(&values[sentValues], byte);
        }
        if (!VOFA_SEND(word, sizeof(float))) {
            return false;
        }
        sentValues++;
    }
#else
    if (!tailPending && (count != 0u)) {
        if (!VOFA_SEND((const uint8_t *)values, count * sizeof(*values))) {
            return false;
        }
        tailPending = true;
    }
#endif
    /* 新段仅在旧段释放后接受，帧尾接受即表示源数据已读完 */
    if (!VOFA_SEND(frameTail.bytes, sizeof(frameTail.bytes))) {
        return false;
    }
#if VOFA_BIG_ENDIAN
    sentValues = 0u;
#else
    tailPending = false;
#endif
    return true;
}
