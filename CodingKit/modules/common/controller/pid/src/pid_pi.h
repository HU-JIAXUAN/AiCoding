/**
 * @file pid_pi.h
 * @brief 先积分的轻量 PI，可接受调用方的最终矢量限幅结果。
 * @author HU JIAXUAN
 * @date 2026-10-23
 */
#ifndef PID_PI_H
#define PID_PI_H

#include "pid.h"

#ifdef __cplusplus
extern "C"
{
#endif

    /** @brief 调用者独占的 PI；三个成员分别为增益及输出单位积分。 */
    typedef struct
    {
        float kp;       /**< 输出单位/输入单位，有限且非负。 */
        float ki;       /**< 输出单位/(输入单位*s)，有限且非负。 */
        float integral; /**< 积分，输出单位；初始化或复位时置零。 */
    } PidPi;

    /** @brief 一个周期的候选，不复制通用 PID，不保存设备或运行状态。 */
    typedef struct
    {
        float proportional; /**< 本拍比例项，输出单位。 */
        float integral;     /**< 本拍已积分并限幅的候选，输出单位。 */
        float output;       /**< 单轴限幅输出，输出单位。 */
        float limit;        /**< 积分及单轴对称上限，输出单位。 */
    } PidPiStep;

    /**
     * @brief 先积分再计算单轴输出，不修改原 PI；失败时 step 不变。
     * @param[in] controller 独占 PI；kp/ki/integral 均有限。
     * @param[in] error 本拍参考减反馈，输入单位。
     * @param[in] periodS 正控制周期，s。
     * @param[in] limit 正输出绝对上限，输出单位。
     * @param[out] step 成功才有效；不得与 PI 重叠。
     * @return PID_OK 或 NULL/FREQ/LIMIT/NUMBER 错误。
     */
    PidStatus pid_pi_eval(const PidPi *controller, float error, float periodS, float limit,
                          PidPiStep *step);

    /**
     * @brief 一次提交积分；外部限幅改变输出时直接跟踪，不重复积分。
     * @param[in,out] controller 产生候选的同一独占 PI；评估后禁止交错修改。
     * @param[in] step 同一周期成功候选，只允许提交一次。
     * @param[in] appliedOutput 外部限幅输出，绝对值不超过 step->limit。
     * @return PID_OK 或 NULL/LIMIT/NUMBER 错误；失败时 PI 不变。
     */
    PidStatus pid_pi_track(PidPi *controller, const PidPiStep *step, float appliedOutput);

#ifdef __cplusplus
}
#endif
#endif
