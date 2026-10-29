/**
 * @file    command.h
 * @brief   命令表类型与名称数值解析接口
 * @details 输入已拆分的名称和值文本；保留类型检查，RW 原始请求由业务生成目标时约束
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#ifndef COMMAND_H
#define COMMAND_H

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    MC_OK = 0,    /* 当前处理成功，或请求状态已经满足 */
    MC_PENDING,   /* 请求已接受，等待后续业务调度 */
    MC_BAD_VALUE, /* 参数值或文本格式无效 */
    MC_BAD_STATE, /* 当前业务状态不允许执行 */
    MC_UNKNOWN,   /* 未识别命令 */
    MC_READ_ONLY  /* 拒绝写入只读项 */
} CommandResult;

typedef enum {
    CC_INVALID = 0, /* 无效项，不允许读写或执行 */
    CC_RW_FLOAT,    /* float 参数，可读可写 */
    CC_RO_FLOAT,    /* float 参数，只读 */
    CC_RW_U8,       /* uint8_t 参数，可读可写 */
    CC_RO_U8,       /* uint8_t 参数，只读 */
    CC_RW_I32,      /* int32_t 参数，可读可写 */
    CC_RO_I32,      /* int32_t 参数，只读 */
    CC_RW_I64,      /* int64_t 参数，可读可写，保持全部整数位 */
    CC_RO_I64,      /* int64_t 参数，只读 */
    CC_RO_U32,      /* 32 位无符号参数，只读 */
    CC_FUNC_FLOAT,  /* float 参数业务动作 */
    CC_FUNC_U8      /* uint8_t 参数业务动作 */
} CommandCode;

typedef union {
    double real;
    int64_t integer;
} CommandValue;

typedef union {
    const volatile void *data;
    CommandResult (*f32)(float value);
    CommandResult (*u8)(uint8_t value);
} CommandAddress;

typedef struct {
    CommandCode code;
    const char *name;
    CommandAddress address; /* RW 保存原始请求；业务生成目标时约束 */
    uint16_t writeStates;   /* 仅 RW；0 沿用公共门禁，非 0 再限定状态位 */
} CommandDef;

/* 主循环传入已去除空格/TAB 的 NUL 结尾名称和值文本，同步使用且不保存 */
CommandResult command_parse(const char *name, const char *valueText);

#endif
