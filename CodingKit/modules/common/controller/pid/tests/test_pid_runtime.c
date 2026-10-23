/**
 * @file test_pid_runtime.c
 * @brief 实际 C 的两阶段回算、原入口等价性与失败原子性测试。
 * @author HU JIAXUAN
 */

#include "pid.h"
#include "pid_pi.h"

#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CHECK(condition)                                                                           \
    do                                                                                             \
    {                                                                                              \
        if (!(condition))                                                                          \
        {                                                                                          \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);                        \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

static void configure(Pid *controller);
static bool compare_state(const PidState *left, const PidState *right);
static bool check_tracking(void);
static bool check_single(void);
static bool check_protocol(void);
static bool check_numbers(void);
static bool check_recovery(void);
static bool check_compat(void);
static bool check_pi(void);

/**
 * @brief 配置一组可精确核算的普通 PI。
 * @param[out] controller 测试对象；不能为空。
 */
static void configure(Pid *controller)
{
    /* 不含被控对象语义，输出与输入的具体单位由使用者决定。 */
    (void)pid_init(controller);
    controller->config.controlFreq = 100.0f;
    controller->config.kp = 1.0f;
    controller->config.ki = 10.0f;
    controller->config.antiWindupGain = 2.0f;
    controller->config.integralLimit = (PidLimit){true, -1.0f, 1.0f};
    controller->input.setpoint = 1.0f;
}

/**
 * @brief 按字段比较状态，排除填充字节影响。
 * @param[in] left 参考状态；不能为空。
 * @param[in] right 实际状态；不能为空。
 * @return 全部观测一致返回 true。
 */
static bool compare_state(const PidState *left, const PidState *right)
{
    const float a[] = {
        left->setpoint,     left->setpointLimited, left->feedback,       left->feedbackLimited,
        left->error,        left->previousError,   left->derivative,     left->derivativeFiltered,
        left->proportional, left->integral,        left->derivativeTerm, left->feedforward,
        left->rawOutput,    left->output};
    const float b[] = {right->setpoint,       right->setpointLimited,
                       right->feedback,       right->feedbackLimited,
                       right->error,          right->previousError,
                       right->derivative,     right->derivativeFiltered,
                       right->proportional,   right->integral,
                       right->derivativeTerm, right->feedforward,
                       right->rawOutput,      right->output};
    size_t index;

    /* Release 构建同样执行检查，不依赖可能被 NDEBUG 删除的 assert。 */
    CHECK(left->saturated == right->saturated);
    CHECK(left->initialized == right->initialized);
    CHECK(left->status == right->status);
    for (index = 0; index < sizeof(a) / sizeof(a[0]); ++index)
    {
        CHECK(fabsf(a[index] - b[index]) <= 1.0e-6f * (1.0f + fabsf(a[index])));
    }

    return true;
}

/**
 * @brief 验证评估无副作用、最终输出回算、单次消费和 P 控制。
 * @return 全部检查通过返回 true。
 */
static bool check_tracking(void)
{
    Pid controller;
    Pid before;
    PidStep step;

    configure(&controller);
    memcpy(&before, &controller, sizeof(before));
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(memcmp(&controller, &before, sizeof(before)) == 0);
    CHECK(step.next.rawOutput == 1.0f);
    CHECK(step.next.integral == 0.0f);
    CHECK(pid_track(&controller, 0.25f, &step) == PID_OK);
    CHECK(fabsf(controller.state.integral + 0.05f) < 1.0e-6f);
    CHECK(controller.state.output == 0.25f);
    CHECK(controller.state.saturated);
    CHECK(!step.ready);
    CHECK(pid_track(&controller, 0.25f, &step) == PID_ERR_STEP);

    /* ki=0 必须清积分，即使积分限幅区间不包含零。 */
    controller.config.ki = 0.0f;
    controller.config.integralLimit = (PidLimit){true, 1.0f, 2.0f};
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(pid_track(&controller, step.next.output, &step) == PID_OK);
    CHECK(controller.state.integral == 0.0f);

    return true;
}

/**
 * @brief 用会触发中间积分裁剪的场景区分一次回算与补丁式二次回算。
 * @return 最终积分符合独立公式返回 true。
 */
static bool check_single(void)
{
    Pid controller;
    PidStep step;

    configure(&controller);
    controller.state.integral = 0.25f;
    controller.config.antiWindupGain = 0.5f;
    controller.config.outputLimit = (PidLimit){true, -0.5f, 0.5f};
    controller.config.integralLimit = (PidLimit){true, -0.3f, 0.3f};

    /* 正确值为 0.2375，先局部积分裁剪再补回算会错误得到 0.225。 */
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(step.next.rawOutput == 1.25f);
    CHECK(step.next.output == 0.5f);
    CHECK(step.next.integral == 0.25f);
    CHECK(pid_track(&controller, -1.0f, &step) == PID_OK);
    CHECK(fabsf(controller.state.integral - 0.2375f) < 1.0e-6f);
    CHECK(controller.state.output == -1.0f);

    return true;
}

/**
 * @brief 检查空指针、跨实例、交错修改和失败后重试。
 * @return 原实例未被失败跟踪改变返回 true。
 */
static bool check_protocol(void)
{
    Pid first;
    Pid second;
    Pid before;
    PidStep step = {0};

    configure(&first);
    configure(&second);
    CHECK(!pid_init(NULL));
    CHECK(pid(NULL) == 0.0f);
    CHECK(pid_eval(NULL, &step) == PID_ERR_NULL && !step.ready);
    CHECK(pid_eval(&first, NULL) == PID_ERR_NULL);
    CHECK(pid_track(&first, 0.0f, NULL) == PID_ERR_NULL);
    CHECK(pid_track(&first, 0.0f, &step) == PID_ERR_STEP);
    CHECK(pid_eval(&first, &step) == PID_OK);
    memcpy(&before, &second, sizeof(before));
    CHECK(pid_track(&second, 0.0f, &step) == PID_ERR_STEP);
    CHECK(memcmp(&second, &before, sizeof(before)) == 0);

    /* 原对象的输入或状态一旦被另一调用改写，旧候选必须被拒绝。 */
    CHECK(pid_eval(&first, &step) == PID_OK);
    first.input.feedback = 0.1f;
    memcpy(&before, &first, sizeof(before));
    CHECK(pid_track(&first, 0.0f, &step) == PID_ERR_STEP);
    CHECK(memcmp(&first, &before, sizeof(before)) == 0);
    CHECK(pid_eval(&first, &step) == PID_OK);
    (void)pid(&first);
    memcpy(&before, &first, sizeof(before));
    CHECK(pid_track(&first, 0.0f, &step) == PID_ERR_STEP);
    CHECK(memcmp(&first, &before, sizeof(before)) == 0);
    CHECK(pid_eval(&first, &step) == PID_OK);
    CHECK(pid_track(NULL, 0.0f, &step) == PID_ERR_NULL && !step.ready);

    return true;
}

/**
 * @brief 验证新路径的非有限数和中间溢出处理。
 * @return 失败不污染控制状态返回 true。
 */
static bool check_numbers(void)
{
    Pid controller;
    Pid before;
    PidStep step;

    configure(&controller);
    controller.input.feedback = NAN;
    memcpy(&before, &controller, sizeof(before));
    CHECK(pid_eval(&controller, &step) == PID_ERR_NUMBER && !step.ready);
    CHECK(memcmp(&controller, &before, sizeof(before)) == 0);
    configure(&controller);
    controller.config.kp = FLT_MAX;
    controller.input.setpoint = 2.0f;
    CHECK(pid_eval(&controller, &step) == PID_ERR_NUMBER && !step.ready);

    configure(&controller);
    memcpy(&before, &controller, sizeof(before));
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(pid_track(&controller, INFINITY, &step) == PID_ERR_NUMBER && !step.ready);
    CHECK(memcmp(&controller, &before, sizeof(before)) == 0);

    /* 积分溢出即使可被限幅隐藏，也应在发布原状态前被拒绝。 */
    configure(&controller);
    controller.config.controlFreq = 1.0f;
    controller.config.ki = FLT_MAX;
    controller.config.antiWindupGain = 0.0f;
    controller.input.setpoint = 2.0f;
    memcpy(&before, &controller, sizeof(before));
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(pid_track(&controller, step.next.output, &step) == PID_ERR_NUMBER);
    CHECK(memcmp(&controller, &before, sizeof(before)) == 0);

    configure(&controller);
    controller.config.controlFreq = 0.0f;
    CHECK(pid_eval(&controller, &step) == PID_ERR_FREQ);
    controller.config.controlFreq = 100.0f;
    controller.config.outputLimit = (PidLimit){true, 1.0f, -1.0f};
    CHECK(pid_eval(&controller, &step) == PID_ERR_LIMIT);
    controller.config.outputLimit = (PidLimit){false, NAN, NAN};
    CHECK(pid_eval(&controller, &step) == PID_OK);
    CHECK(pid_track(&controller, step.next.output, &step) == PID_OK);

    return true;
}

/**
 * @brief 以外部饱和驱动独立一阶模型，检查持续回算及退出饱和。
 * @return 稳态积分和恢复反馈满足独立预期返回 true。
 */
static bool check_recovery(void)
{
    Pid controller;
    PidStep step;
    float feedback = 0.0f;
    int tick;

    configure(&controller);
    controller.config.controlFreq = 10000.0f;
    controller.config.ki = 1000.0f;
    controller.config.antiWindupGain = 1.0f;
    controller.config.integralLimit = (PidLimit){true, -10.0f, 10.0f};
    for (tick = 0; tick < 1500; ++tick)
    {
        float applied;

        /* 局部 outputLimit 关闭，回算只能来自外部实际输出。 */
        controller.input.feedback = feedback;
        controller.input.setpoint = tick < 1000 ? 1.0f : 0.0f;
        CHECK(pid_eval(&controller, &step) == PID_OK);
        applied = step.next.rawOutput;
        if (applied > 0.5f)
        {
            applied = 0.5f;
        }
        if (applied < -0.5f)
        {
            applied = -0.5f;
        }
        CHECK(pid_track(&controller, applied, &step) == PID_OK);
        feedback = 0.9048374180f * feedback + (1.0f - 0.9048374180f) * applied;
        if (tick == 999)
        {
            CHECK(fabsf(feedback - 0.5f) < 0.02f);
            CHECK(fabsf(controller.state.integral - 0.5f) < 0.02f);
        }
        if (tick >= 1099)
        {
            CHECK(fabsf(feedback) < 0.02f);
        }
    }

    return true;
}

/**
 * @brief 在多周期下比较新路径与旧入口的全部状态。
 * @return 六组成功路径均等价返回 true。
 */
static bool check_compat(void)
{
    int scenario;

    for (scenario = 0; scenario < 6; ++scenario)
    {
        Pid legacy;
        Pid staged;
        PidStep step;
        int tick;

        configure(&legacy);
        legacy.config.controlFreq = 1000.0f;
        legacy.config.ki = scenario % 2 == 0 ? 0.0f : 12.0f;
        legacy.config.kd = scenario >= 2 ? 0.003f : 0.0f;
        legacy.config.derivativeFilterCoef = scenario == 4 ? 1.5f : 0.65f;
        legacy.config.setpointRateEnable = scenario >= 3;
        legacy.config.setpointRate = 2.0f;
        legacy.config.outputLimit = (PidLimit){true, -0.8f, 0.8f};
        legacy.config.integralLimit = (PidLimit){true, -0.3f, 0.3f};
        legacy.config.setpointLimit = (PidLimit){true, -1.0f, 1.0f};
        legacy.config.feedbackLimit = (PidLimit){true, -0.6f, 0.6f};
        legacy.config.errorLimit = (PidLimit){true, -0.4f, 0.4f};
        legacy.config.deadband = 0.1f;
        staged = legacy;
        for (tick = 0; tick < 500; ++tick)
        {
            legacy.input.setpoint = (float)((tick % 17) - 8) * 0.125f;
            legacy.input.feedback = (float)((tick % 11) - 5) * 0.0625f;
            legacy.input.feedforward = (float)((tick % 3) - 1) * 0.03125f;
            staged.input = legacy.input;
            (void)pid(&legacy);
            CHECK(pid_eval(&staged, &step) == PID_OK);
            CHECK(pid_track(&staged, step.next.output, &step) == PID_OK);
            CHECK(compare_state(&legacy.state, &staged.state));
        }
    }

    return true;
}

/** @brief PI 先积分、单轴限幅和一次矢量输出跟踪。 */
static bool check_pi(void)
{
    PidPi controller = {1.0f, 10.0f, 0.0f};
    PidPiStep step;
    CHECK(pid_pi_eval(&controller, 1.0f, 0.01f, 1.0f, &step) == PID_OK);
    CHECK(controller.integral == 0.0f);
    CHECK(fabsf(step.integral - 0.1f) < 1e-6f && step.output == 1.0f);
    CHECK(pid_pi_track(&controller, &step, 0.70710678f) == PID_OK);
    CHECK(fabsf(controller.integral - (-0.29289322f)) < 1e-6f);
    CHECK(pid_pi_eval(&controller, 1.0f, 0.01f, 1.0f, &step) == PID_OK);
    CHECK(fabsf(step.output - 0.80710678f) < 1e-6f);
    CHECK(pid_pi_track(&controller, &step, step.output) == PID_OK);
    CHECK(fabsf(controller.integral - (-0.19289322f)) < 1e-6f);
    CHECK(pid_pi_eval(&controller, INFINITY, 0.01f, 1.0f, &step) == PID_ERR_NUMBER);
    CHECK(pid_pi_eval(&controller, 0.0f, 0.0f, 1.0f, &step) == PID_ERR_FREQ);
    CHECK(pid_pi_eval(NULL, 0.0f, 0.01f, 1.0f, &step) == PID_ERR_NULL);
    controller.ki = 0.0f;
    CHECK(pid_pi_eval(&controller, 1.0f, 0.01f, 1.0f, &step) == PID_OK);
    CHECK(pid_pi_track(&controller, &step, 0.5f) == PID_OK && controller.integral == 0.0f);
    return true;
}

/**
 * @brief 执行全部两阶段测试。
 * @return 通过返回 EXIT_SUCCESS。
 */
int main(void)
{
    /* 每组失败直接使宿主测试失败，所有优化级别均有效。 */
    return check_tracking() && check_single() && check_protocol() && check_numbers() &&
                   check_recovery() && check_compat() && check_pi()
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
}
