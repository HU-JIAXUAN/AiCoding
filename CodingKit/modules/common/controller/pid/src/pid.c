#include "pid.h"

#include <math.h>
#include <string.h>

/**
 * @file pid.c
 * @brief 通用 PID 控制单元实现。
 * @author HU JIAXUAN
 *
 * 本文件实现目标限幅、目标变化率限制、误差调节、微分滤波、
 * 输出限幅、输出死区和积分抗饱和。
 */

static float pid_abs(float value);
static bool pid_limit_valid(PidLimit limit);
static float pid_clamp(float value, PidLimit limit);
static float pid_clean_filter_coef(float coef);
static PidStatus pid_check_config(const PidConfig *config);
static float pid_get_period(const PidConfig *config);
static float pid_prepare_setpoint(const PidConfig *config, const PidState *state, float period,
                                  float setpoint);
static float pid_apply_deadband(float value, float deadband);
static void pid_update_state(PidState *state, PidInput input, float setpointLimited,
                             float feedbackLimited, float error, float derivative, float rawOutput,
                             float limitedOutput);
static bool pid_finite_limit(PidLimit limit);
static PidStatus pid_check_numbers(const Pid *controller);
static void pid_prepare(Pid *controller);
static float pid_integral(const PidConfig *config, const PidState *state, float appliedOutput);

/**
 * @brief 计算 float 绝对值，避免在强实时路径中额外依赖 libm。
 * @param[in] value 输入值。
 * @return 绝对值。
 */
static float pid_abs(float value)
{
    /* 只用于死区判断，不改变控制器状态。 */
    if (value < 0.0f)
    {
        return -value;
    }

    return value;
}

/**
 * @brief 检查限幅参数是否有效。
 * @param[in] limit 限幅参数。
 * @return 参数有效返回 true，否则返回 false。
 */
static bool pid_limit_valid(PidLimit limit)
{
    /* 未启用的限幅不检查上下界，便于用户只配置必要项。 */
    if (!limit.enable)
    {
        return true;
    }

    return limit.min <= limit.max;
}

/**
 * @brief 根据限幅参数裁剪输入值。
 * @param[in] value 输入值。
 * @param[in] limit 限幅参数。
 * @return 裁剪后的值。
 */
static float pid_clamp(float value, PidLimit limit)
{
    /* 同一个内部函数覆盖目标、反馈、误差、积分和输出限幅。 */
    if (!limit.enable)
    {
        return value;
    }
    if (value > limit.max)
    {
        return limit.max;
    }
    if (value < limit.min)
    {
        return limit.min;
    }

    return value;
}

/**
 * @brief 将微分滤波系数限制在 [0, 1]。
 * @param[in] coef 原始滤波系数。
 * @return 清理后的滤波系数。
 */
static float pid_clean_filter_coef(float coef)
{
    /* 错误滤波系数不应导致控制器状态发散。 */
    if (coef < 0.0f)
    {
        return 0.0f;
    }
    if (coef > 1.0f)
    {
        return 1.0f;
    }

    return coef;
}

/**
 * @brief 检查配置是否可用于当前控制更新。
 * @param[in] config 控制器配置。
 * @return PID_OK 表示有效，否则返回错误码。
 */
static PidStatus pid_check_config(const PidConfig *config)
{
    if (config->controlFreq <= PID_EPSILON)
    {
        return PID_ERR_FREQ;
    }
    if (!pid_limit_valid(config->setpointLimit) || !pid_limit_valid(config->feedbackLimit) ||
        !pid_limit_valid(config->errorLimit) || !pid_limit_valid(config->integralLimit) ||
        !pid_limit_valid(config->outputLimit))
    {
        return PID_ERR_LIMIT;
    }
    if (config->setpointRateEnable && (config->setpointRate < 0.0f))
    {
        return PID_ERR_LIMIT;
    }
    if (config->antiWindupGain < 0.0f)
    {
        return PID_ERR_LIMIT;
    }

    return PID_OK;
}

/**
 * @brief 根据控制频率计算控制周期。
 * @param[in] config 控制器配置。
 * @return 控制周期，单位 s。
 */
static float pid_get_period(const PidConfig *config)
{
    /* 用户配置控制频率，内部使用控制周期完成离散积分和微分。 */
    return 1.0f / config->controlFreq;
}

/**
 * @brief 对目标值执行限幅和斜率限制。
 * @param[in] config 控制器配置。
 * @param[in] state 控制器状态。
 * @param[in] period 控制周期，单位 s。
 * @param[in] setpoint 原始目标值，单位同被控量；标幺时为 pu。
 * @return 处理后的目标值，单位同被控量；标幺时为 pu。
 */
static float pid_prepare_setpoint(const PidConfig *config, const PidState *state, float period,
                                  float setpoint)
{
    float setpointLimited;

    /* 先做绝对范围限制，再做每拍变化量限制。 */
    setpointLimited = pid_clamp(setpoint, config->setpointLimit);
    if (config->setpointRateEnable && state->initialized)
    {
        const float maxStep = config->setpointRate * period;
        const float delta = setpointLimited - state->setpointLimited;

        if (delta > maxStep)
        {
            setpointLimited = state->setpointLimited + maxStep;
        }
        else if (delta < -maxStep)
        {
            setpointLimited = state->setpointLimited - maxStep;
        }
    }

    return setpointLimited;
}

/**
 * @brief 根据输出死区处理控制量。
 * @param[in] value 原始输出，单位同输出；标幺时为 pu。
 * @param[in] deadband 死区宽度，单位同输出；标幺时为 pu。
 * @return 死区处理后的输出，单位同输出；标幺时为 pu。
 */
static float pid_apply_deadband(float value, float deadband)
{
    /* 死区放在通道求和之后，避免隐藏 P/I/D 内部状态。 */
    if (deadband <= 0.0f)
    {
        return value;
    }
    if (pid_abs(value) < deadband)
    {
        return 0.0f;
    }

    return value;
}

/**
 * @brief 更新可观测状态字段。
 * @param[in,out] state 控制器状态。
 * @param[in] input 控制器输入。
 * @param[in] setpointLimited 限幅后的目标值。
 * @param[in] feedbackLimited 限幅后的反馈值。
 * @param[in] error 当前误差。
 * @param[in] derivative 当前误差微分。
 * @param[in] rawOutput 限幅前输出。
 * @param[in] limitedOutput 限幅后输出。
 */
static void pid_update_state(PidState *state, PidInput input, float setpointLimited,
                             float feedbackLimited, float error, float derivative, float rawOutput,
                             float limitedOutput)
{
    /* 统一在控制周期尾部更新观测量，避免中间状态被外部误读。 */
    state->setpoint = input.setpoint;
    state->setpointLimited = setpointLimited;
    state->feedback = input.feedback;
    state->feedbackLimited = feedbackLimited;
    state->previousError = state->error;
    state->error = error;
    state->derivative = derivative;
    state->rawOutput = rawOutput;
    state->output = limitedOutput;
    state->saturated = (limitedOutput != rawOutput);
    state->initialized = true;
    state->status = PID_OK;
}

/**
 * @brief 检查已启用限幅的数值是否有限。
 * @param[in] limit 可选限幅。
 * @return 未启用或边界均有限返回 true。
 */
static bool pid_finite_limit(PidLimit limit)
{
    /* 未使用边界不影响本次两阶段计算。 */
    return !limit.enable || (isfinite(limit.min) && isfinite(limit.max));
}

/**
 * @brief 检查两阶段路径实际持有的数值，旧入口保留既有校验语义。
 * @param[in] controller 已存在的实例或候选；不能为空。
 * @return 所有必需数值有限返回 PID_OK。
 */
static PidStatus pid_check_numbers(const Pid *controller)
{
    const PidConfig *config = &controller->config;
    const PidInput *input = &controller->input;
    const PidState *state = &controller->state;

    /* 显式字段访问不假设结构体中 float 连续排列。 */
    if (!isfinite(config->kp) || !isfinite(config->ki) || !isfinite(config->kd) ||
        !isfinite(config->controlFreq) || !isfinite(config->setpointRate) ||
        !isfinite(config->derivativeFilterCoef) || !isfinite(config->antiWindupGain) ||
        !isfinite(config->deadband) || !pid_finite_limit(config->setpointLimit) ||
        !pid_finite_limit(config->feedbackLimit) || !pid_finite_limit(config->errorLimit) ||
        !pid_finite_limit(config->integralLimit) || !pid_finite_limit(config->outputLimit) ||
        !isfinite(input->setpoint) || !isfinite(input->feedback) || !isfinite(input->feedforward) ||
        !isfinite(state->setpoint) || !isfinite(state->setpointLimited) ||
        !isfinite(state->feedback) || !isfinite(state->feedbackLimited) ||
        !isfinite(state->error) || !isfinite(state->previousError) ||
        !isfinite(state->derivative) || !isfinite(state->derivativeFiltered) ||
        !isfinite(state->proportional) || !isfinite(state->integral) ||
        !isfinite(state->derivativeTerm) || !isfinite(state->feedforward) ||
        !isfinite(state->rawOutput) || !isfinite(state->output))
    {
        return PID_ERR_NUMBER;
    }

    return PID_OK;
}

/**
 * @brief 共用原入口的目标整形和输出评估，不推进积分。
 * @param[in,out] controller 实例或候选；调用方已校验配置。
 * @note 保留求和、死区、单轴输出限幅的原有顺序。
 */
static void pid_prepare(Pid *controller)
{
    const PidConfig *config = &controller->config;
    PidState *state = &controller->state;
    const PidInput input = controller->input;
    const float period = pid_get_period(config);
    float setpointLimited;
    float feedbackLimited;
    float error;
    float derivative;
    float filterCoef;
    float rawOutput;
    float limitedOutput;

    /* 目标值、反馈值和误差都在控制器内部统一限幅。 */
    setpointLimited = pid_prepare_setpoint(config, state, period, input.setpoint);
    feedbackLimited = pid_clamp(input.feedback, config->feedbackLimit);
    error = pid_clamp(setpointLimited - feedbackLimited, config->errorLimit);

    /* 第一拍没有历史误差，因此微分项置 0，避免启动尖峰。 */
    derivative = 0.0f;
    if (state->initialized)
    {
        derivative = (error - state->error) / period;
    }
    filterCoef = pid_clean_filter_coef(config->derivativeFilterCoef);
    state->derivativeFiltered =
        (filterCoef * state->derivativeFiltered) + ((1.0f - filterCoef) * derivative);

    /* kp、ki、kd 为 0.0f 时，对应通道自然关闭。 */
    state->proportional = config->kp * error;
    state->derivativeTerm = config->kd * state->derivativeFiltered;
    state->feedforward = input.feedforward;

    rawOutput = state->proportional + state->integral + state->derivativeTerm + state->feedforward;
    rawOutput = pid_apply_deadband(rawOutput, config->deadband);
    limitedOutput = pid_clamp(rawOutput, config->outputLimit);

    pid_update_state(state, input, setpointLimited, feedbackLimited, error, derivative, rawOutput,
                     limitedOutput);
}

/**
 * @brief 以最终施加输出计算尚未限幅的下一积分。
 * @param[in] config 当前配置；不能为空。
 * @param[in] state 本周期已评估的状态，integral 仍为旧积分。
 * @param[in] appliedOutput 最终施加输出，单位同输出。
 * @return 下一积分候选，单位同输出；是否有限由调用路径决定。
 */
static float pid_integral(const PidConfig *config, const PidState *state, float appliedOutput)
{
    float period;
    float antiWindupError;

    /* 关闭积分时不计算未使用的差值，避免无意义的浮点溢出。 */
    if (config->ki == 0.0f)
    {
        return 0.0f;
    }
    period = pid_get_period(config);
    antiWindupError = appliedOutput - state->rawOutput;
    return state->integral +
           (config->ki * (state->error + (config->antiWindupGain * antiWindupError)) * period);
}

/**
 * @brief 初始化 PID 控制器对象。
 * @param[out] controller 控制器对象。
 * @return true 表示初始化成功，false 表示对象为空。
 *
 * 实现方法：清零整个对象，写入默认控制频率、微分滤波系数、抗饱和增益和状态码。
 * 该函数不替代工程参数配置，实际 kp、ki、kd 和限幅仍应由上层设置。
 */
bool pid_init(Pid *controller)
{
    if (controller == (Pid *)0)
    {
        return false;
    }

    *controller = (Pid){0};
    controller->config.controlFreq = PID_DEFAULT_CONTROL_FREQ_HZ;
    controller->config.derivativeFilterCoef = 0.0f;
    controller->config.antiWindupGain = 1.0f;
    controller->state.status = PID_OK;

    return true;
}

/**
 * @brief 执行兼容的单周期入口，局部输出作为最终回算值。
 * @param[in,out] controller 控制器对象；NULL 返回零。
 * @return 当前输出，单位同输出；非法配置保留旧输出。
 */
float pid(Pid *controller)
{
    const PidConfig *config;
    PidState *state;
    PidStatus status;

    if (controller == (Pid *)0)
    {
        return 0.0f;
    }
    config = &controller->config;
    state = &controller->state;
    status = pid_check_config(config);
    if (status != PID_OK)
    {
        /* 兼容原入口：配置非法时仅记录状态，保留上一拍输出。 */
        state->status = status;
        return state->output;
    }

    pid_prepare(controller);
    if (config->ki != 0.0f)
    {
        state->integral =
            pid_clamp(pid_integral(config, state, state->output), config->integralLimit);
    }
    else
    {
        state->integral = 0.0f;
    }

    return state->output;
}

/**
 * @brief 评估一个候选周期，不发布原实例的中间状态。
 * @param[in] controller 原实例，生命周期覆盖后续跟踪。
 * @param[out] step 独立候选存储；不能为空且不与原实例重叠。
 * @return PID_OK 时候选有效；失败时原实例不变。
 */
PidStatus pid_eval(const Pid *controller, PidStep *step)
{
    Pid candidate;
    PidStatus status;

    if (step == (PidStep *)0)
    {
        return PID_ERR_NULL;
    }
    *step = (PidStep){0};
    if (controller == (const Pid *)0)
    {
        return PID_ERR_NULL;
    }
    status = pid_check_config(&controller->config);
    if (status != PID_OK)
    {
        return status;
    }
    status = pid_check_numbers(controller);
    if (status != PID_OK)
    {
        return status;
    }

    /* 字节快照用于识别评估后的交错修改，不拿结构体填充参与数值计算。 */
    memcpy(&candidate, controller, sizeof(candidate));
    pid_prepare(&candidate);
    status = pid_check_numbers(&candidate);
    if (status != PID_OK)
    {
        return status;
    }
    memcpy(&step->before, controller, sizeof(step->before));
    step->next = candidate.state;
    step->owner = controller;
    step->ready = true;

    return PID_OK;
}

/**
 * @brief 跟踪最终输出并一次性发布状态，避免下游限幅被漏算或重复回算。
 * @param[in,out] controller 评估时的同一原实例。
 * @param[in] appliedOutput 最终施加输出，单位同输出。
 * @param[in,out] step 有效候选，尝试后即失效。
 * @return 失败时原实例不变；PID_OK 表示完整状态已发布。
 */
PidStatus pid_track(Pid *controller, float appliedOutput, PidStep *step)
{
    PidState next;
    float integralNext;

    if (step == (PidStep *)0)
    {
        return PID_ERR_NULL;
    }
    if (controller == (Pid *)0)
    {
        step->ready = false;
        return PID_ERR_NULL;
    }
    if (!step->ready || step->owner != controller)
    {
        step->ready = false;
        return PID_ERR_STEP;
    }

    /* 无论成功与否都消费候选；重试必须重新评估，原实例在检查前不写入。 */
    step->ready = false;
    if (memcmp(controller, &step->before, sizeof(*controller)) != 0)
    {
        return PID_ERR_STEP;
    }
    if (!isfinite(appliedOutput))
    {
        return PID_ERR_NUMBER;
    }
    next = step->next;
    integralNext = pid_integral(&controller->config, &next, appliedOutput);
    if (!isfinite(integralNext))
    {
        return PID_ERR_NUMBER;
    }
    next.integral = controller->config.ki == 0.0f
                        ? 0.0f
                        : pid_clamp(integralNext, controller->config.integralLimit);
    next.output = appliedOutput;
    next.saturated = appliedOutput != next.rawOutput;
    controller->state = next;

    return PID_OK;
}
