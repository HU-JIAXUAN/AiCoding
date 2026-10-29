/**
 * @file    recorder.h
 * @brief   数据采集与完成块
 * @details 单一 ISR 按完整数据组发布采集块，单一主循环使用完后归还
 *          工程业务区提供信号表；调用方决定采集节拍，两个采集数组由本模块维护
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#ifndef RECORDER_H
#define RECORDER_H

#include <stdbool.h>
#include <stddef.h>

/* 地址指向的实际 RAM 类型 */
typedef enum {
    RS_U8,   /* uint8_t  */
    RS_U16,  /* uint16_t */
    RS_I16,  /* int16_t  */
    RS_I32,  /* int32_t  */
    RS_U32,  /* 无符号 32 位整数，按对象字节读取 */
    RS_I64,  /* int64_t 连续位置或整圈数 */
    RS_FLOAT /* float，无需数值类型转换 */
} SignalType;

typedef struct {
    SignalType type;              /* 源变量的实际类型 */
    const volatile void *address; /* 源变量地址 */
    float scale;                  /* 原始值到工程量的倍率 */
} RecorderSignal;

/* 地址和长度由 recorder 维护；主循环只读数据，整块用完后清 ready */
typedef struct {
    const float *addr;   /* 采集数据首地址 */
    size_t count;        /* ready 时有效的 float 元素数 */
    volatile bool ready; /* 置 true 后数据保持，主循环清 false 后允许复用 */
} RecorderBlock;

/* 工程业务区提供信号地址和倍率，表项顺序即通道号 */
extern const RecorderSignal mDecodePtrTbl[];
/* 采集表项数，由实际表自动计算 */
extern const size_t mDecodePtrCount;

/* 第 0/1 项的 addr 分别保存 A/B 数组首地址，不复制采集数据 */
extern RecorderBlock g_recorderBlocks[2];

/* 调用一次采集一组 float 数据；调用前源值应已更新，分频由调用方管理 */
void recorder(void);

#endif
