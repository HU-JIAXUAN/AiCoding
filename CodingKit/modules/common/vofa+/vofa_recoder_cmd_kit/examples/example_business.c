/**
 * @file    example_business.c
 * @brief   无硬件依赖的命令执行示例
 * @details 原始请求写 RAM；只读、存储类型和状态许可由业务执行器解释
 * @author  HU JIAXUAN
 * @date    2026-10-29
 * @version 1.0.0
 */
#include "example_business.h"
#include <float.h>
#include <math.h>

volatile ExampleRam exampleRam = {
    255u, 60000u, -1234, -123456789, UINT32_C(0xf1234567), INT64_C(9007199254740993), 1.25f, EXAMPLE_STOP};

/* 示例直接生效；实际项目由自己的状态机决定何时执行 */
CommandResult example_set_mode(uint8_t mode)
{
    if (mode > EXAMPLE_BLOCKED) {
        return MC_BAD_VALUE;
    }
    exampleRam.state = mode;
    return MC_OK;
}

/* 动作自行检查业务状态，不使用普通参数的 writeStates */
CommandResult example_add_offset(float offset)
{
    if (exampleRam.state == EXAMPLE_BLOCKED) {
        return MC_BAD_STATE;
    }
    exampleRam.setting += offset;
    return MC_OK;
}

/* 链接绑定就是提交入口，不增加运行时注册或中转路由 */
CommandResult command_execute(const CommandDef *command, CommandValue value)
{
    if (((command->code == CC_RW_FLOAT) || (command->code == CC_FUNC_FLOAT)) &&
        (!isfinite(value.real) || (value.real < -FLT_MAX) || (value.real > FLT_MAX))) {
        return MC_BAD_VALUE;
    }
    if (command->code == CC_FUNC_FLOAT) {
        return command->address.f32((float)value.real);
    }
    if (command->code == CC_FUNC_U8) {
        if ((value.integer < 0) || (value.integer > UINT8_MAX)) {
            return MC_BAD_VALUE;
        }
        return command->address.u8((uint8_t)value.integer);
    }
    switch (command->code) {
        case CC_RO_FLOAT:
        case CC_RO_U8:
        case CC_RO_I32:
        case CC_RO_I64:
        case CC_RO_U32:
            return MC_READ_ONLY;
        default:
            break;
    }
    if (((command->code == CC_RW_U8) && ((value.integer < 0) || (value.integer > UINT8_MAX))) ||
        ((command->code == CC_RW_I32) && ((value.integer < INT32_MIN) || (value.integer > INT32_MAX)))) {
        return MC_BAD_VALUE;
    }
    if ((command->code != CC_RW_FLOAT) && (command->code != CC_RW_U8) && (command->code != CC_RW_I32) &&
        (command->code != CC_RW_I64)) {
        return MC_UNKNOWN;
    }
    if ((exampleRam.state == EXAMPLE_BLOCKED) ||
        ((command->writeStates != 0u) && ((command->writeStates & (1u << exampleRam.state)) == 0u))) {
        return MC_BAD_STATE;
    }
    switch (command->code) {
        case CC_RW_FLOAT:
            *(volatile float *)command->address.data = (float)value.real;
            break;
        case CC_RW_U8:
            *(volatile uint8_t *)command->address.data = (uint8_t)value.integer;
            break;
        case CC_RW_I32:
            *(volatile int32_t *)command->address.data = (int32_t)value.integer;
            break;
        case CC_RW_I64:
            *(volatile int64_t *)command->address.data = value.integer;
            break;
        default:
            return MC_UNKNOWN;
    }
    return MC_OK;
}
