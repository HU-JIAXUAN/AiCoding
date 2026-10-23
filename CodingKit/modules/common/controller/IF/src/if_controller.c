/**
 * @file if_controller.c
 * @brief D 轴强拉、零电压交接和带电流闭环的软件频率启动。
 * @author HU JIAXUAN
 */
#include "if_controller.h"
#include "foc_math.h"
#include "foc_svpwm.h"

#include <float.h>
#include <math.h>
#include <stddef.h>

#if FLT_RADIX != 2 || FLT_MANT_DIG < 24 || FLT_MAX_EXP < 128
#error "IF requires at least binary32 float"
#endif
#if defined(__FAST_MATH__) || (defined(__FINITE_MATH_ONLY__) && __FINITE_MATH_ONLY__ > 0)
#error "IF requires finite-number checks"
#endif

static bool if_ticks(float seconds, float periodS, uint32_t *ticks);
static void if_clear(IfController *controller);
static IfStatus if_fail(IfController *controller, IfOutput *output, IfStatus status);
static bool if_advance(float *angle, float *compensation, float increment);
static bool if_control(IfController *controller, const IfInput *input, IfOutput *output);

/** @brief 秒换算为最近的控制周期；正时间至少一拍，拒绝计数溢出。 */
static bool if_ticks(float seconds, float periodS, uint32_t *ticks)
{
    const float count = roundf(seconds / periodS);
    if (!isfinite(seconds) || seconds < 0.0f || !isfinite(count) || count >= 4294967296.0f)
    {
        return false;
    }
    *ticks = seconds == 0.0f ? 0u : (uint32_t)fmaxf(1.0f, count);
    return true;
}

/** @brief 用同一配置重建两个小 PI，清除强拉或故障遗留积分。 */
static void if_clear(IfController *controller)
{
    controller->pi[0] = (PidPi){controller->config.piD.kp, controller->config.piD.ki, 0.0f};
    controller->pi[1] = (PidPi){controller->config.piQ.kp, controller->config.piQ.ki, 0.0f};
}

/** @brief 失败当拍停止激励，直到显式停止或复位；硬件由调用方关断。 */
static IfStatus if_fail(IfController *controller, IfOutput *output, IfStatus status)
{
    if_clear(controller);
    controller->state = IF_STATE_FAULT;
    controller->status = status;
    *output = (IfOutput){0};
    output->state = IF_STATE_FAULT;
    return status;
}

/** @brief 有界补偿加法保留微小频率，单拍增量小于 pi，无无界环绕。 */
static bool if_advance(float *angle, float *compensation, float increment)
{
    const float addition = increment - *compensation;
    float next = *angle + addition;
    if (increment == 0.0f)
    {
        return true;
    }
    *compensation = (next - *angle) - addition;
    if (next < 0.0f)
    {
        const float wrapped = next + FOC_TWO_PI;
        *compensation += (wrapped - FOC_TWO_PI) - next;
        next = wrapped;
    }
    if (next >= FOC_TWO_PI)
    {
        next -= FOC_TWO_PI;
    }
    *angle = next;
    return isfinite(next) && isfinite(*compensation);
}

/** @brief 两轴反馈、先积分 PI、统一限压和共享调制，不访问设备。 */
static bool if_control(IfController *controller, const IfInput *input, IfOutput *output)
{
    const IfConfig *config = &controller->config;
    const float limit = fminf(config->voltageLimitV, (1.0f - 2.0f * config->dutyMargin) *
                                                         FOC_ONE_BY_SQRT3 * input->busVoltageV);
    const float mean =
        (input->phaseCurrentA[0] + input->phaseCurrentA[1] + input->phaseCurrentA[2]) / 3.0f;
    const FocPhase phase = {input->phaseCurrentA[0] - mean, input->phaseCurrentA[1] - mean,
                            input->phaseCurrentA[2] - mean};
    const FocSinCos angle = foc_sincos(output->thetaRad);
    const FocDq feedback = foc_park(foc_clarke(phase), angle);
    PidPiStep steps[2];
    FocDq voltage;
    FocSvpwm pwm;
    float magnitude;
    int axis;

    if (!isfinite(limit) || limit <= 0.0f || !isfinite(feedback.d) || !isfinite(feedback.q))
    {
        return false;
    }
    output->currentFeedbackDqA[0] = feedback.d;
    output->currentFeedbackDqA[1] = feedback.q;
    for (axis = 0; axis < 2; ++axis)
    {
        const float error = output->currentRefDqA[axis] - output->currentFeedbackDqA[axis];
        if (pid_pi_eval(&controller->pi[axis], error, config->periodS, limit, &steps[axis]) !=
            PID_OK)
        {
            return false;
        }
        output->voltageDqV[axis] = steps[axis].output;
        if (steps[axis].output != steps[axis].proportional + steps[axis].integral)
        {
            output->voltageLimited = true;
        }
    }
    magnitude = hypotf(output->voltageDqV[0], output->voltageDqV[1]);
    if (!isfinite(magnitude))
    {
        return false;
    }
    if (magnitude > limit)
    {
        output->voltageDqV[0] *= limit / magnitude;
        output->voltageDqV[1] *= limit / magnitude;
        output->voltageLimited = true;
    }
    voltage = (FocDq){output->voltageDqV[0], output->voltageDqV[1]};
    if (!foc_svpwm_init(&pwm))
    {
        return false;
    }
    pwm.input.modulation = foc_inv_park(voltage, angle);
    pwm.input.modulation.alpha /= input->busVoltageV;
    pwm.input.modulation.beta /= input->busVoltageV;
    pwm.config.maxModulation = limit / input->busVoltageV;
    if (!foc_svpwm(&pwm) || !pwm.state.valid || !isfinite(pwm.state.scale) ||
        fabsf(pwm.state.scale - 1.0f) > 2e-6f)
    {
        return false;
    }
    output->duty[0] = pwm.state.dutyA;
    output->duty[1] = pwm.state.dutyB;
    output->duty[2] = pwm.state.dutyC;
    for (axis = 0; axis < 3; ++axis)
    {
        const float duty = output->duty[axis];
        if (!isfinite(duty) || duty < config->dutyMargin - 2e-6f ||
            duty > 1.0f - config->dutyMargin + 2e-6f)
        {
            return false;
        }
        output->duty[axis] = foc_clamp(duty, config->dutyMargin, 1.0f - config->dutyMargin);
    }
    /* 限幅后的指令只提交一次，不复制整个控制器或通用 PID 快照。 */
    for (axis = 0; axis < 2; ++axis)
    {
        if (pid_pi_track(&controller->pi[axis], &steps[axis], output->voltageDqV[axis]) != PID_OK)
        {
            return false;
        }
    }
    return true;
}

/** @brief 校验物理配置与有界时间计数，成功后才替换原对象。 */
IfStatus if_init(IfController *controller, const IfConfig *config)
{
    IfController next = {0};
    uint32_t holdTicks;
    const IfPiConfig *pi;
    int axis;

    if (controller == NULL || config == NULL)
    {
        return IF_ERR_NULL;
    }
    if (!isfinite(config->periodS) || config->periodS <= 0.0f || !isfinite(config->currentLimitA) ||
        config->currentLimitA <= 0.0f || !isfinite(config->voltageLimitV) ||
        config->voltageLimitV <= 0.0f || !isfinite(config->busMinV) || config->busMinV <= 0.0f ||
        !isfinite(config->dutyMargin) || config->dutyMargin < 0.0f || config->dutyMargin >= 0.5f ||
        !isfinite(config->alignAngleRad) || config->alignAngleRad < 0.0f ||
        config->alignAngleRad >= FOC_TWO_PI || !isfinite(config->alignCurrentA) ||
        config->alignCurrentA <= 0.0f || config->alignCurrentA > config->currentLimitA)
    {
        return IF_ERR_CONFIG;
    }
    for (axis = 0; axis < 2; ++axis)
    {
        pi = axis == 0 ? &config->piD : &config->piQ;
        if (!isfinite(pi->kp) || pi->kp <= 0.0f || !isfinite(pi->ki) || pi->ki < 0.0f)
        {
            return IF_ERR_CONFIG;
        }
    }
    if (!if_ticks(config->alignRampS, config->periodS, &next.alignRampTicks) ||
        !if_ticks(config->alignHoldS, config->periodS, &holdTicks) ||
        !if_ticks(config->frequencyRampS, config->periodS, &next.rampTicks) ||
        holdTicks >= UINT32_MAX - next.alignRampTicks)
    {
        return IF_ERR_CONFIG;
    }
    next.alignTicks = next.alignRampTicks + holdTicks;
    if (next.alignTicks == 0u)
    {
        return IF_ERR_CONFIG;
    }
    next.config = *config;
    next.initialized = true;
    *controller = next;
    return if_reset(controller);
}

/** @brief 保留配置，清启动计数、积分、错误与相位；不产生有效输出。 */
IfStatus if_reset(IfController *controller)
{
    if (controller == NULL)
    {
        return IF_ERR_NULL;
    }
    if (!controller->initialized)
    {
        return IF_ERR_STATE;
    }
    if_clear(controller);
    controller->thetaRad = controller->config.alignAngleRad;
    controller->thetaCompRad = 0.0f;
    controller->tick = 0u;
    controller->state = IF_STATE_STOPPED;
    controller->status = IF_OK;
    return IF_OK;
}

/** @brief 每拍准备启动参考并闭环；对齐、交接与运行共用同一电流链。 */
IfStatus if_update(IfController *controller, const IfInput *input, IfOutput *output)
{
    float angle, compensation;
    int phase;

    if (output != NULL)
    {
        *output = (IfOutput){0};
    }
    if (controller == NULL || input == NULL || output == NULL)
    {
        return IF_ERR_NULL;
    }
    output->state = controller->state;
    if (!controller->initialized)
    {
        return IF_ERR_STATE;
    }
    /* 停止优先于采样检查，允许在采样失效时立即关闭并重新武装。 */
    if (!input->enable)
    {
        (void)if_reset(controller);
        output->state = IF_STATE_STOPPED;
        return IF_OK;
    }
    if (controller->state == IF_STATE_FAULT)
    {
        return controller->status;
    }
    if (!input->sampleValid || !isfinite(input->busVoltageV) ||
        input->busVoltageV < controller->config.busMinV || !isfinite(input->currentA) ||
        !isfinite(input->frequencyHz) ||
        fabsf(input->frequencyHz) * controller->config.periodS >= 0.5f)
    {
        return if_fail(controller, output, IF_ERR_INPUT);
    }
    for (phase = 0; phase < 3; ++phase)
    {
        if (!isfinite(input->phaseCurrentA[phase]))
        {
            return if_fail(controller, output, IF_ERR_INPUT);
        }
    }
    if (controller->state == IF_STATE_STOPPED)
    {
        controller->state = IF_STATE_ALIGN;
    }
    if (controller->state == IF_STATE_ALIGN && controller->tick == controller->alignTicks)
    {
        if_clear(controller);
        controller->tick = 0u;
        controller->state = IF_STATE_HANDOFF;
        output->state = IF_STATE_HANDOFF;
        output->thetaRad = controller->thetaRad;
        output->duty[0] = output->duty[1] = output->duty[2] = 0.5f;
        output->outputValid = true;
        return IF_OK;
    }
    if (controller->state == IF_STATE_HANDOFF)
    {
        controller->thetaRad += input->currentA < 0.0f ? FOC_TWO_PI / 4.0f : -FOC_TWO_PI / 4.0f;
        if (controller->thetaRad < 0.0f)
        {
            controller->thetaRad += FOC_TWO_PI;
        }
        else if (controller->thetaRad >= FOC_TWO_PI)
        {
            controller->thetaRad -= FOC_TWO_PI;
        }
        controller->thetaCompRad = 0.0f;
        controller->state = IF_STATE_RUNNING;
    }
    if (controller->state == IF_STATE_ALIGN)
    {
        ++controller->tick;
        output->currentRefDqA[0] = controller->config.alignCurrentA;
        if (controller->tick < controller->alignRampTicks)
        {
            output->currentRefDqA[0] *= (float)controller->tick / controller->alignRampTicks;
        }
    }
    else
    {
        if (controller->tick < controller->rampTicks)
        {
            ++controller->tick;
        }
        output->frequencyHz = input->frequencyHz;
        if (controller->rampTicks != 0u)
        {
            output->frequencyHz *= (float)controller->tick / controller->rampTicks;
        }
        output->currentRefDqA[1] = foc_clamp(input->currentA, -controller->config.currentLimitA,
                                             controller->config.currentLimitA);
        output->currentLimited = output->currentRefDqA[1] != input->currentA;
    }
    angle = controller->thetaRad;
    compensation = controller->thetaCompRad;
    if (!if_advance(&angle, &compensation,
                    (output->frequencyHz * controller->config.periodS) * FOC_TWO_PI))
    {
        return if_fail(controller, output, IF_ERR_CALC);
    }
    output->thetaRad = angle;
    if (!if_control(controller, input, output))
    {
        return if_fail(controller, output, IF_ERR_CALC);
    }
    controller->thetaRad = angle;
    controller->thetaCompRad = compensation;
    output->state = controller->state;
    output->outputValid = true;
    return IF_OK;
}
