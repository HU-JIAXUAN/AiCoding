/**
 * @file    example_business.h
 * @brief   独立示例的业务 RAM 与命令执行声明
 * @details 仅演示工程绑定；通用模块不拥有业务状态或执行规则
 * @author  HU JIAXUAN
 * @date    2026-10-29
 * @version 1.0.0
 */
#ifndef EXAMPLE_BUSINESS_H
#define EXAMPLE_BUSINESS_H

#include "command.h"

typedef enum { EXAMPLE_STOP, EXAMPLE_RUN, EXAMPLE_BLOCKED } ExampleState;

typedef struct {
    uint8_t level;
    uint16_t angle;
    int16_t current;
    int32_t signedWord;
    uint32_t unsignedWord;
    int64_t position;
    float setting;
    uint8_t state;
} ExampleRam;

extern volatile ExampleRam exampleRam;

/* 同步检查类型和业务许可后写入原始请求；实际工程在此实现所需临界区 */
CommandResult command_execute(const CommandDef *command, CommandValue value);
/* 示例动作：切换运行状态 */
CommandResult example_set_mode(uint8_t mode);
/* 示例动作：给现有请求加偏移，受业务状态限制 */
CommandResult example_add_offset(float offset);

#endif
