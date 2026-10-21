/**
 * @file if_controller.c
 * @brief I-f 相电流到 duty 的完整离散控制链。
 * @author HU JIAXUAN
 */

#include "if_controller.h"
#include "foc_math.h"
#include "foc_svpwm.h"

#include <float.h>
#include <math.h>

#if FLT_RADIX != 2 || FLT_MANT_DIG < 24 || FLT_MAX_EXP < 128 || FLT_MIN_EXP > -125
#error "IF requires at least binary32 float precision and exponent range"
#endif
#if defined(__FAST_MATH__) || (defined(__FINITE_MATH_ONLY__) && __FINITE_MATH_ONLY__ > 0)
#error "IF requires finite-number checks; fast-math is unsupported"
#endif

#define IF_DUTY_TOL (2.0e-6f) /**< duty 边界和调制舍入容差，无单位。 */

static bool if_positive(float value);
static bool if_pi_valid(const IfPiConfig *pi, const IfConfig *config);
static bool if_config_valid(const IfConfig *config);
static bool if_clear(IfController *controller);
static IfStatus if_invalid(IfOutput *output, IfState state, IfStatus status);
static IfStatus if_fail(IfController *controller, IfOutput *output, IfStatus status);
static FocDq if_clip(FocDq value, float limit, bool *limited);
static FocDq if_slew(FocDq previous, FocDq target, float step);
static float if_move(float previous, float target, float step);
static void if_reference(IfController *next, const IfInput *input, IfOutput *output);
static IfStatus if_input_valid(const IfController *next, const IfInput *input, bool starting);
static bool if_feedback(const IfInput *input, FocSinCos angle, FocDq *feedback);
static bool if_modulate(FocDq voltage, float bus, float limit, float margin, IfOutput *output,
                        FocSinCos angle);
static bool if_control(IfController *next, const IfInput *input, IfOutput *output);
static bool if_advance(IfController *next, IfOutput *output);

/** @brief 判断需保持非零的有限正量。 */
static bool if_positive(float value)
{
    return isfinite(value) && value > 0.0f;
}

/** @brief 检查单轴 PI 的物理范围及回算离散增益。 */
static bool if_pi_valid(const IfPiConfig *pi, const IfConfig *config)
{
    float gain;

    if (!if_positive(pi->kp) || !isfinite(pi->ki) || pi->ki < 0.0f || !isfinite(pi->kaw) ||
        pi->kaw < 0.0f || !if_positive(pi->integralLimitV) ||
        pi->integralLimitV > config->voltageLimitV)
    {
        return false;
    }
    if (pi->ki == 0.0f)
    {
        return true;
    }
    gain = pi->ki * pi->kaw;
    if (!if_positive(gain) || !if_positive(pi->ki * config->periodS))
    {
        return false;
    }
    gain *= config->periodS;
    return if_positive(gain) && gain <= 1.0f;
}

/** @brief 在改写对象前检查配置、乘积及 float 斜坡可推进性。 */
static bool if_config_valid(const IfConfig *config)
{
    float currentStep;
    float frequencyStep;
    float frequencyPeriod;
    float controlFrequency;

    if (!if_positive(config->periodS) || !if_positive(config->currentLimitA) ||
        !if_positive(config->frequencyLimitHz) || !if_positive(config->currentSlewAps) ||
        !if_positive(config->frequencySlewHzps) || !if_positive(config->voltageLimitV) ||
        !if_positive(config->busMinV) || !isfinite(config->dutyMargin) ||
        config->dutyMargin < 0.0f || config->dutyMargin >= 0.5f)
    {
        return false;
    }
    /* 零斜率、正量下溢、倒数溢出均不能变成隐含的关闭选项。 */
    currentStep = config->currentSlewAps * config->periodS;
    frequencyStep = config->frequencySlewHzps * config->periodS;
    frequencyPeriod = config->frequencyLimitHz * config->periodS;
    controlFrequency = 1.0f / config->periodS;
    if (!if_positive(currentStep) || !if_positive(frequencyStep) || !if_positive(frequencyPeriod) ||
        frequencyPeriod >= 0.5f || !if_positive(controlFrequency) ||
        controlFrequency <= PID_EPSILON)
    {
        return false;
    }
    return config->currentLimitA - fminf(currentStep, config->currentLimitA) <
               config->currentLimitA &&
           config->frequencyLimitHz - fminf(frequencyStep, config->frequencyLimitHz) <
               config->frequencyLimitHz &&
           if_pi_valid(&config->piD, config) && if_pi_valid(&config->piQ, config);
}

/** @brief 保留配置与相位，通过共享初始化入口清参考、积分和故障。 */
static bool if_clear(IfController *controller)
{
    int axis;

    for (axis = 0; axis < 2; ++axis)
    {
        const IfPiConfig *pi = axis == 0 ? &controller->config.piD : &controller->config.piQ;
        Pid *shared = &controller->pi[axis];

        if (!pid_init(shared))
        {
            return false;
        }
        shared->config.controlFreq = 1.0f / controller->config.periodS;
        shared->config.kp = pi->kp;
        shared->config.ki = pi->ki;
        shared->config.antiWindupGain = pi->kaw;
        shared->config.integralLimit = (PidLimit){true, -pi->integralLimitV, pi->integralLimitV};
        controller->currentRefDqA[axis] = 0.0f;
    }
    controller->frequencyRefHz = 0.0f;
    controller->fault = IF_OK;
    controller->state = IF_STATE_STOPPED;
    return true;
}

/** @brief 完整覆盖无效结果，防止调用方继续使用旧 duty 或观测量。 */
static IfStatus if_invalid(IfOutput *output, IfState state, IfStatus status)
{
    if (output != (IfOutput *)0)
    {
        *output = (IfOutput){0};
        output->state = state;
        output->status = status;
    }
    return status;
}

/** @brief 锁存本次首次故障，清运行激励且保留故障前的相位。 */
static IfStatus if_fail(IfController *controller, IfOutput *output, IfStatus status)
{
    if (!if_clear(controller))
    {
        status = IF_ERR_CALC;
    }
    controller->state = IF_STATE_FAULT;
    controller->fault = status;
    return if_invalid(output, controller->state, status);
}

/** @brief 用缩放范数径向限幅，避免大数平方溢出后伪装成有效输出。 */
static FocDq if_clip(FocDq value, float limit, bool *limited)
{
    const float scale = fmaxf(fabsf(value.d), fabsf(value.q));
    float d;
    float q;
    float length;
    float radius;

    *limited = false;
    if (scale == 0.0f)
    {
        return value;
    }
    d = value.d / scale;
    q = value.q / scale;
    length = sqrtf(d * d + q * q);
    radius = limit / length;
    if (scale > radius)
    {
        *limited = true;
        value = (FocDq){d * radius, q * radius};
    }
    return value;
}

/** @brief 沿电流目标的直线限制单步欧氏距离，末步精确落到目标。 */
static FocDq if_slew(FocDq previous, FocDq target, float step)
{
    const float scale =
        fmaxf(fmaxf(fabsf(previous.d), fabsf(previous.q)), fmaxf(fabsf(target.d), fabsf(target.q)));
    FocDq difference;
    float length;
    float distance;

    if (scale == 0.0f || scale <= step / 4.0f)
    {
        return target;
    }
    /* 先缩放再求差，允许两个相反的大有限参考而不先溢出。 */
    difference.d = target.d / scale - previous.d / scale;
    difference.q = target.q / scale - previous.q / scale;
    length = sqrtf(difference.d * difference.d + difference.q * difference.q);
    if (length <= step / scale)
    {
        return target;
    }
    distance = step / length;
    return (FocDq){previous.d + difference.d * distance, previous.q + difference.q * distance};
}

/** @brief 沿同号目标或零点推进频率，不越过本段终点。 */
static float if_move(float previous, float target, float step)
{
    const float difference = target - previous;

    if (fabsf(difference) <= step)
    {
        return target;
    }
    return previous + copysignf(step, difference);
}

/** @brief 生成本周期参考；反向先过零，受控停机先降频率再降电流。 */
static void if_reference(IfController *next, const IfInput *input, IfOutput *output)
{
    const IfConfig *config = &next->config;
    const float currentStep = config->currentSlewAps * config->periodS;
    const float frequencyStep = config->frequencySlewHzps * config->periodS;
    const FocDq previous = {next->currentRefDqA[0], next->currentRefDqA[1]};
    FocDq target = {0.0f, 0.0f};
    FocDq reference = previous;
    float frequencyTarget = 0.0f;
    float frequencyGoal = 0.0f;
    bool limited;

    if (next->state == IF_STATE_STOPPING)
    {
        if (next->frequencyRefHz == 0.0f)
        {
            reference = if_slew(previous, target, currentStep);
        }
    }
    else
    {
        target = if_clip((FocDq){input->currentTargetDqA[0], input->currentTargetDqA[1]},
                         config->currentLimitA, &limited);
        if (limited)
        {
            output->flags |= IF_FLAG_CURRENT_LIMITED;
        }
        reference = if_slew(previous, target, currentStep);
        frequencyTarget = foc_clamp(input->frequencyTargetHz, -config->frequencyLimitHz,
                                    config->frequencyLimitHz);
        if (frequencyTarget != input->frequencyTargetHz)
        {
            output->flags |= IF_FLAG_FREQUENCY_LIMITED;
        }
        frequencyGoal = frequencyTarget;
        if ((next->frequencyRefHz > 0.0f && frequencyTarget < 0.0f) ||
            (next->frequencyRefHz < 0.0f && frequencyTarget > 0.0f))
        {
            frequencyGoal = 0.0f;
        }
    }
    next->currentRefDqA[0] = reference.d;
    next->currentRefDqA[1] = reference.q;
    next->frequencyRefHz = if_move(next->frequencyRefHz, frequencyGoal, frequencyStep);
    if (reference.d != target.d || reference.q != target.q)
    {
        output->flags |= IF_FLAG_CURRENT_SLEW;
    }
    if (next->frequencyRefHz != frequencyTarget)
    {
        output->flags |= IF_FLAG_FREQUENCY_SLEW;
    }
}

/** @brief 按消费顺序校验采样、数值、母线及启动角度；忽略无关字段。 */
static IfStatus if_input_valid(const IfController *next, const IfInput *input, bool starting)
{
    if (!input->sampleValid)
    {
        return IF_ERR_SAMPLE;
    }
    if (!isfinite(input->phaseCurrentA[0]) || !isfinite(input->phaseCurrentA[1]) ||
        !isfinite(input->phaseCurrentA[2]) || !isfinite(input->busVoltageV))
    {
        return IF_ERR_NUMBER;
    }
    if (next->state == IF_STATE_RUNNING &&
        (!isfinite(input->frequencyTargetHz) || !isfinite(input->currentTargetDqA[0]) ||
         !isfinite(input->currentTargetDqA[1])))
    {
        return IF_ERR_NUMBER;
    }
    if (starting && !isfinite(input->startAngleRad))
    {
        return IF_ERR_NUMBER;
    }
    if (input->busVoltageV < next->config.busMinV)
    {
        return IF_ERR_VBUS;
    }
    if (starting && (input->startAngleRad < 0.0f || input->startAngleRad >= FOC_TWO_PI))
    {
        return IF_ERR_RANGE;
    }
    return IF_OK;
}

/** @brief 缩放去零序后复用 Clarke/Park，避免三相求和先溢出。 */
static bool if_feedback(const IfInput *input, FocSinCos angle, FocDq *feedback)
{
    const float scale =
        fmaxf(fabsf(input->phaseCurrentA[0]),
              fmaxf(fabsf(input->phaseCurrentA[1]), fabsf(input->phaseCurrentA[2])));
    FocPhase phase = {0.0f, 0.0f, 0.0f};
    float mean;

    if (scale != 0.0f)
    {
        phase = (FocPhase){input->phaseCurrentA[0] / scale, input->phaseCurrentA[1] / scale,
                           input->phaseCurrentA[2] / scale};
        mean = (phase.a + phase.b + phase.c) / 3.0f;
        phase = (FocPhase){phase.a - mean, phase.b - mean, phase.c - mean};
    }
    *feedback = foc_park(foc_clarke(phase), angle);
    feedback->d *= scale;
    feedback->q *= scale;
    return isfinite(feedback->d) && isfinite(feedback->q);
}

/** @brief 显式设置线性调制圆盘，检查隐藏裁剪并从最终 duty 重建 dq 电压。 */
static bool if_modulate(FocDq voltage, float bus, float limit, float margin, IfOutput *output,
                        FocSinCos angle)
{
    FocSvpwm pwm;
    FocAb modulation = foc_inv_park(voltage, angle);
    FocPhase phase;
    FocPhase applied;
    FocDq reconstructed;
    float expected[3];
    float common;
    float mean;
    int leg;

    if (!foc_svpwm_init(&pwm))
    {
        return false;
    }
    modulation.alpha /= bus;
    modulation.beta /= bus;
    pwm.config.maxModulation = limit / bus;
    pwm.input.modulation = modulation;
    if (!if_positive(pwm.config.maxModulation) || !isfinite(modulation.alpha) ||
        !isfinite(modulation.beta) || !foc_svpwm(&pwm) || !pwm.state.valid ||
        !isfinite(pwm.state.scale) || fabsf(pwm.state.scale - 1.0f) > IF_DUTY_TOL)
    {
        return false;
    }
    /* 和调制前的理想中心化结果比较，不能只信底层 valid 或逐相硬裁剪。 */
    phase = foc_inv_clarke(modulation);
    common =
        -0.5f * (fmaxf(phase.a, fmaxf(phase.b, phase.c)) + fminf(phase.a, fminf(phase.b, phase.c)));
    expected[0] = 0.5f + phase.a + common;
    expected[1] = 0.5f + phase.b + common;
    expected[2] = 0.5f + phase.c + common;
    output->duty[0] = pwm.state.dutyA;
    output->duty[1] = pwm.state.dutyB;
    output->duty[2] = pwm.state.dutyC;
    for (leg = 0; leg < 3; ++leg)
    {
        const float duty = output->duty[leg];
        const float corrected = foc_clamp(duty, margin, 1.0f - margin);

        if (!isfinite(duty) || !isfinite(expected[leg]) || expected[leg] < margin - IF_DUTY_TOL ||
            expected[leg] > 1.0f - margin + IF_DUTY_TOL ||
            fabsf(duty - expected[leg]) > IF_DUTY_TOL || fabsf(duty - corrected) > IF_DUTY_TOL)
        {
            return false;
        }
        if (duty != corrected)
        {
            output->flags |= IF_FLAG_DUTY_ROUNDOFF;
        }
        output->duty[leg] = corrected;
    }
    /* 先在归一化域重建再乘母线，避免不必要的大电压中间差值。 */
    mean = (output->duty[0] + output->duty[1] + output->duty[2]) / 3.0f;
    applied = (FocPhase){output->duty[0] - mean, output->duty[1] - mean, output->duty[2] - mean};
    reconstructed = foc_park(foc_clarke(applied), angle);
    output->voltageAppliedDqV[0] = reconstructed.d * bus;
    output->voltageAppliedDqV[1] = reconstructed.q * bus;
    return isfinite(output->voltageAppliedDqV[0]) && isfinite(output->voltageAppliedDqV[1]);
}

/** @brief 在候选实例上完成两轴评估、矢量限压、最终 duty 与一次回算。 */
static bool if_control(IfController *next, const IfInput *input, IfOutput *output)
{
    const FocSinCos angle = foc_sincos(next->thetaRad);
    const float busLimit = (1.0f - 2.0f * next->config.dutyMargin) * FOC_ONE_BY_SQRT3;
    PidStep steps[2];
    FocDq feedback;
    FocDq voltage;
    bool limited;
    int axis;

    output->voltageLimitV = fminf(next->config.voltageLimitV, busLimit * input->busVoltageV);
    if (!if_positive(output->voltageLimitV) || !if_feedback(input, angle, &feedback))
    {
        return false;
    }
    output->currentFeedbackDqA[0] = feedback.d;
    output->currentFeedbackDqA[1] = feedback.q;
    for (axis = 0; axis < 2; ++axis)
    {
        next->pi[axis].input.setpoint = next->currentRefDqA[axis];
        next->pi[axis].input.feedback = output->currentFeedbackDqA[axis];
        if (pid_eval(&next->pi[axis], &steps[axis]) != PID_OK)
        {
            return false;
        }
        output->voltageRawDqV[axis] = steps[axis].next.rawOutput;
    }
    voltage = if_clip((FocDq){output->voltageRawDqV[0], output->voltageRawDqV[1]},
                      output->voltageLimitV, &limited);
    if (limited)
    {
        output->flags |= IF_FLAG_VOLTAGE_LIMITED;
    }
    if (!if_modulate(voltage, input->busVoltageV, output->voltageLimitV, next->config.dutyMargin,
                     output, angle))
    {
        return false;
    }
    for (axis = 0; axis < 2; ++axis)
    {
        if (pid_track(&next->pi[axis], output->voltageAppliedDqV[axis], &steps[axis]) != PID_OK)
        {
            return false;
        }
        output->integralDqV[axis] = next->pi[axis].state.integral;
    }
    return true;
}

/** @brief 用有界补偿加法推进相位，每周期至多一次环绕；零频冻结补偿。 */
static bool if_advance(IfController *next, IfOutput *output)
{
    float increment;
    float angle;

    output->thetaUsedRad = next->thetaRad;
    output->deltaThetaRad = (next->frequencyRefHz * next->config.periodS) * FOC_TWO_PI;
    if (output->deltaThetaRad == 0.0f)
    {
        return true;
    }
    increment = output->deltaThetaRad - next->thetaCompRad;
    angle = next->thetaRad + increment;
    next->thetaCompRad = (angle - next->thetaRad) - increment;
    if (angle < 0.0f)
    {
        const float wrapped = angle + FOC_TWO_PI;

        /* 负微小增量加到 2*pi 可能舍入成边界，保留这次舍入而非吞掉增量。 */
        next->thetaCompRad += (wrapped - FOC_TWO_PI) - angle;
        angle = wrapped;
    }
    if (angle >= FOC_TWO_PI)
    {
        angle -= FOC_TWO_PI;
    }
    next->thetaRad = angle;
    return isfinite(angle) && isfinite(next->thetaCompRad) && angle >= 0.0f && angle < FOC_TWO_PI;
}

/** @brief 原子应用完整有效配置；活动对象与无效配置均保持不变。 */
IfStatus if_init(IfController *controller, const IfConfig *config)
{
    IfController next = {0};

    if (controller == (IfController *)0 || config == (const IfConfig *)0)
    {
        return IF_ERR_NULL;
    }
    if (controller->state != IF_STATE_UNINITIALIZED && controller->state != IF_STATE_STOPPED &&
        controller->state != IF_STATE_FAULT)
    {
        return IF_ERR_STATE;
    }
    if (!if_config_valid(config))
    {
        return IF_ERR_CONFIG;
    }
    next.config = *config;
    if (!if_clear(&next))
    {
        return IF_ERR_CALC;
    }
    *controller = next;
    return IF_OK;
}

/** @brief 通过同一已验证配置重新初始化，清相位但不启动。 */
IfStatus if_reset(IfController *controller)
{
    IfConfig config;

    if (controller == (IfController *)0)
    {
        return IF_ERR_NULL;
    }
    if (controller->state != IF_STATE_STOPPED && controller->state != IF_STATE_FAULT)
    {
        return IF_ERR_STATE;
    }
    config = controller->config;
    return if_init(controller, &config);
}

/** @brief 单周期事务：候选中计算，全部成功才发布；失败仅发布清激励的锁存故障。 */
IfStatus if_update(IfController *controller, const IfInput *input, IfOutput *output)
{
    IfController next;
    IfInput snapshot;
    IfOutput result = {0};
    IfStatus status;
    bool starting;

    if (controller == (IfController *)0 || input == (const IfInput *)0 || output == (IfOutput *)0)
    {
        return if_invalid(
            output, controller == (IfController *)0 ? IF_STATE_UNINITIALIZED : controller->state,
            IF_ERR_NULL);
    }
    if (controller->state < IF_STATE_STOPPED || controller->state > IF_STATE_FAULT)
    {
        return if_invalid(output, controller->state, IF_ERR_STATE);
    }
    if (controller->state == IF_STATE_FAULT)
    {
        return if_invalid(output, controller->state, controller->fault);
    }
    snapshot = *input;
    if (snapshot.action < IF_ACTION_KEEP || snapshot.action > IF_ACTION_DISABLE)
    {
        return if_fail(controller, output, IF_ERR_ACTION);
    }
    /* 立即禁用在采样检查之前生效；停止态不消费任何数值输入。 */
    if (snapshot.action == IF_ACTION_DISABLE)
    {
        if (!if_clear(controller))
        {
            return if_fail(controller, output, IF_ERR_CALC);
        }
        return if_invalid(output, controller->state, IF_OK);
    }
    starting = controller->state == IF_STATE_STOPPED && snapshot.action == IF_ACTION_START;
    if (controller->state == IF_STATE_STOPPED && !starting)
    {
        return if_invalid(output, controller->state, IF_OK);
    }
    next = *controller;
    if (starting)
    {
        next.state = IF_STATE_RUNNING;
    }
    else if (snapshot.action == IF_ACTION_STOP)
    {
        next.state = IF_STATE_STOPPING;
    }
    status = if_input_valid(&next, &snapshot, starting);
    if (status != IF_OK)
    {
        return if_fail(controller, output, status);
    }
    if (starting)
    {
        next.thetaRad = snapshot.startAngleRad;
        next.thetaCompRad = 0.0f;
    }
    if_reference(&next, &snapshot, &result);
    if (next.state == IF_STATE_STOPPING && next.frequencyRefHz == 0.0f &&
        next.currentRefDqA[0] == 0.0f && next.currentRefDqA[1] == 0.0f)
    {
        if (!if_clear(&next))
        {
            return if_fail(controller, output, IF_ERR_CALC);
        }
        *controller = next;
        return if_invalid(output, next.state, IF_OK);
    }
    if (!if_control(&next, &snapshot, &result) || !if_advance(&next, &result))
    {
        return if_fail(controller, output, IF_ERR_CALC);
    }
    result.currentRefDqA[0] = next.currentRefDqA[0];
    result.currentRefDqA[1] = next.currentRefDqA[1];
    result.frequencyRefHz = next.frequencyRefHz;
    result.state = next.state;
    result.status = IF_OK;
    *controller = next;
    result.outputValid = true;
    *output = result;
    return IF_OK;
}
