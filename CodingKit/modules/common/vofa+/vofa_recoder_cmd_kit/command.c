/**
 * @file    command.c
 * @brief   工程命令与采集表、名称查找及数值解析
 * @details 工程绑定集中在表区；名称匹配先于数值转换，原始请求和状态规则交由业务执行层
 * @author  HU JIAXUAN
 * @date    2026-10-28
 * @version 1.0.0
 */
#include "command.h"

/* 工程业务绑定：移植时只替换本区的业务声明、命令表和采集表 */
#include "recorder.h"
#include "example_business.h"
#include <errno.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

/* 类型、名称、实际地址/动作、可写状态；执行规则由业务实现 */
const CommandDef mCommands[] = {
    {CC_RW_FLOAT, "demo.setting", {&exampleRam.setting}, 0},
    {CC_RW_I64, "demo.position", {&exampleRam.position}, 0},
    {CC_RW_U8, "demo.level", {&exampleRam.level}, 0},
    {CC_RW_I32, "demo.word", {&exampleRam.signedWord}, 0},
    {CC_RO_U32, "demo.readonly", {&exampleRam.unsignedWord}, 0},
    {CC_RW_FLOAT, "demo.runOnly", {&exampleRam.setting}, 1u << EXAMPLE_RUN},
    {CC_FUNC_U8, "demo.mode", {.u8 = example_set_mode}, 0},
    {CC_FUNC_FLOAT, "demo.offset", {.f32 = example_add_offset}, 0},
};
const size_t mCommandCount = sizeof(mCommands) / sizeof(mCommands[0]);

/* 类型、实际地址、倍率；顺序即观测通道顺序 */
const RecorderSignal mDecodePtrTbl[] = {
    {RS_U8, &exampleRam.level, 1.0f},         {RS_U16, &exampleRam.angle, 0.5f},
    {RS_I16, &exampleRam.current, 0.25f},     {RS_I32, &exampleRam.signedWord, 1.0f},
    {RS_U32, &exampleRam.unsignedWord, 1.0f}, {RS_I64, &exampleRam.position, 1.0f},
    {RS_FLOAT, &exampleRam.setting, 2.0f},
};
const size_t mDecodePtrCount = sizeof(mDecodePtrTbl) / sizeof(mDecodePtrTbl[0]);

/************************ 命令解析 ************************/
/* 整数值和边界不经过浮点，执行结果直接返回给调用方 */
CommandResult command_parse(const char *name, const char *valueText)
{
    const CommandDef *command = NULL;
    CommandValue value;
    char *end;
    size_t i;

    for (i = 0u; i < mCommandCount; i++) {
        if (strcmp(name, mCommands[i].name) == 0) {
            command = &mCommands[i];
            break;
        }
    }
    if (command == NULL) {
        return MC_UNKNOWN;
    }
    errno = 0;
    if ((command->code == CC_RW_U8) || (command->code == CC_RW_I32) || (command->code == CC_RW_I64) ||
        (command->code == CC_FUNC_U8)) {
        value.integer = strtoll(valueText, &end, 10);
        if (errno == ERANGE) {
            return MC_BAD_VALUE;
        }
    } else {
        value.real = (double)strtof(valueText, &end);
        if ((errno == ERANGE) || !isfinite(value.real)) {
            return MC_BAD_VALUE;
        }
    }
    if ((end == valueText) || (*end != '\0')) {
        return MC_BAD_VALUE;
    }
    return command_execute(command, value);
}
