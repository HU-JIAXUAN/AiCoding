/**
 * @file  vofa_cfg.h
 * @brief VOFA 适配层接口（示例）。vofa.c/.h 不用改；复制本对文件去改。
 * @version 1.0.0
 */

#ifndef VOFA_CFG_H
#define VOFA_CFG_H

#include "vofa.h"

#ifdef __cplusplus
extern "C"
{
#endif

    /* 示例配置：换成你自己的控制结构体。在线调参改它的成员。 */
    typedef struct
    {
        float kp;
        float ki;
        float kd;
    } app_pid_t;
    typedef struct
    {
        app_pid_t pos_pid;
        app_pid_t vel_pid;
        app_pid_t cur_pid;
    } app_config_t;

    /** @brief 初始化：注册 VOFA 回调。 */
    void Vofa_CfgInit(app_config_t *config);

    /** @brief 主循环服务：收帧 + 调参；验证模式下改为发正弦波（见 vofa_cfg.c）。 */
    void Vofa_CfgProcess(void);

#ifdef __cplusplus
}
#endif

#endif /* VOFA_CFG_H */
