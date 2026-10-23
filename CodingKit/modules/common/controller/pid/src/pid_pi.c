/**
 * @file pid_pi.c
 * @brief 先积分 PI 与外部矢量限幅跟踪；不改变旧 PID 接口或行为。
 * @author HU JIAXUAN
 * @date 2026-10-23
 */
#include "pid_pi.h"

#include <math.h>
#include <stddef.h>

/** @brief 计算一拍候选；ki=0 时保持纯比例，不残留积分。 */
PidStatus pid_pi_eval(const PidPi *controller, float error, float periodS, float limit,
                      PidPiStep *step)
{
    PidPiStep next;
    float raw;

    if (controller == NULL || step == NULL)
    {
        return PID_ERR_NULL;
    }
    if (!isfinite(periodS) || periodS <= 0.0f)
    {
        return PID_ERR_FREQ;
    }
    if (!isfinite(limit) || limit <= 0.0f)
    {
        return PID_ERR_LIMIT;
    }
    if (!isfinite(controller->kp) || controller->kp < 0.0f || !isfinite(controller->ki) ||
        controller->ki < 0.0f || !isfinite(controller->integral) || !isfinite(error))
    {
        return PID_ERR_NUMBER;
    }
    /* 先计算积分候选；乘积溢出必须报错，不能通过 clamp 掩盖。 */
    next.proportional = controller->kp * error;
    next.integral =
        controller->ki == 0.0f ? 0.0f : controller->integral + (controller->ki * periodS) * error;
    if (!isfinite(next.proportional) || !isfinite(next.integral))
    {
        return PID_ERR_NUMBER;
    }
    next.integral = fminf(limit, fmaxf(-limit, next.integral));
    raw = next.proportional + next.integral;
    if (!isfinite(raw))
    {
        return PID_ERR_NUMBER;
    }
    next.output = fminf(limit, fmaxf(-limit, raw));
    next.limit = limit;
    *step = next;
    return PID_OK;
}

/** @brief 饱和时跟踪实际指令，未饱和时提交本拍积分候选。 */
PidStatus pid_pi_track(PidPi *controller, const PidPiStep *step, float appliedOutput)
{
    float integral;

    if (controller == NULL || step == NULL)
    {
        return PID_ERR_NULL;
    }
    if (!isfinite(step->limit) || step->limit <= 0.0f || fabsf(appliedOutput) > step->limit)
    {
        return PID_ERR_LIMIT;
    }
    if (!isfinite(appliedOutput) || !isfinite(step->output) || !isfinite(step->proportional) ||
        !isfinite(step->integral) || !isfinite(controller->ki) || controller->ki < 0.0f)
    {
        return PID_ERR_NUMBER;
    }
    integral = appliedOutput == step->output ? step->integral : appliedOutput - step->proportional;
    if (!isfinite(integral))
    {
        return PID_ERR_NUMBER;
    }
    controller->integral =
        controller->ki == 0.0f ? 0.0f : fminf(step->limit, fmaxf(-step->limit, integral));
    return PID_OK;
}
