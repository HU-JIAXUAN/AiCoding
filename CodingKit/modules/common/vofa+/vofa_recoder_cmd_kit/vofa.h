/**
 * @file    vofa.h
 * @brief   VOFA 发送、完整帧解析与接口注册
 * @details 发送通过接口注册，完整帧拆分后同步提交名称和值，不维护接收状态
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#ifndef VOFA_H
#define VOFA_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* 接口注册：异步后端只借用一段，旧段释放后才接受下一段；也可在接受时完成复制
 * 返回 false 不保留本次指针；发送端读取源数据所需的内存可见性由适配保证
 */
#include "command.h"
extern bool example_transport_send(const uint8_t *addr, size_t len);
#define VOFA_SEND(addr, len) example_transport_send((addr), (len))
#define VOFA_COMMAND(name, valueText) command_parse((name), (valueText))

/* 本机 float 字节序：0 为小端，1 为大端 */
#define VOFA_BIG_ENDIAN (0u)
/* 按小端顺序取出 float 的第 index 个字节 */
#define VOFA_FLOAT_BYTE(addr, index) (((const unsigned char *)(addr))[VOFA_BIG_ENDIAN ? (3u - (index)) : (index)])

/* 非阻塞推进数据段和固定帧尾；false 时保持同一地址、数量及数据重试
 * true 表示帧尾已被接受、源数据已读完，可以归还源缓冲；帧尾可能仍在发送
 * 单调用上下文；完成前不得取消、换端口/协议或插入其他发送
 */
bool vofa_send(const float *values, size_t count);

/* 主循环传入完整可写帧，length 不含 NUL，frame[length] 是缓冲内的可写 NUL
 * 原地拆分并去除空格/TAB，同步提交命令；不保存输入
 */
void vofa_parse(char *frame, size_t length);

#endif
