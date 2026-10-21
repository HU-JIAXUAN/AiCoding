/**
 * @file test_if_control.c
 * @brief 通过真实 IF 入口核对时序、两轴调节、最终 duty 与最小生命周期。
 * @author HU JIAXUAN
 */

#include "if_controller.h"

#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TEST_PI (3.14159265358979323846) /**< 独立双精度圆周率。 */
#define CHECK(condition)                                                                           \
    do                                                                                             \
    {                                                                                              \
        if (!(condition))                                                                          \
        {                                                                                          \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);                        \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

static IfConfig test_config(void);
static IfInput test_input(void);
static bool check_invalid(const IfOutput *output, IfState state, IfStatus status);
static void reconstruct(const IfOutput *output, float bus, double voltage[2]);
static bool check_projection(void);
static bool check_reference(void);
static bool check_voltage(void);
static bool check_tracking(void);
static bool check_lifecycle(void);
static bool check_errors(void);
static bool check_config(void);
static bool check_sweep(void);
static bool check_phase(void);

/** @brief 创建测试配置，不作为电机调参默认值交付。 */
static IfConfig test_config(void)
{
    const IfPiConfig pi = {1.0f, 0.0f, 0.0f, 20.0f};
    const IfConfig config = {0.01f, 20.0f, 10.0f, 10000.0f, 1000.0f, 20.0f, 1.0f, 0.0f, pi, pi};

    return config;
}

/** @brief 创建零电流、有效母线和显式启动快照。 */
static IfInput test_input(void)
{
    IfInput input = {0};

    input.action = IF_ACTION_START;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    return input;
}

/** @brief 无效输出必须整体清空数值，不能只清 outputValid。 */
static bool check_invalid(const IfOutput *output, IfState state, IfStatus status)
{
    int axis;

    CHECK(output->state == state && output->status == status && !output->outputValid);
    CHECK(output->flags == 0u && output->frequencyRefHz == 0.0f && output->thetaUsedRad == 0.0f);
    CHECK(output->deltaThetaRad == 0.0f && output->voltageLimitV == 0.0f);
    for (axis = 0; axis < 3; ++axis)
    {
        CHECK(output->duty[axis] == 0.0f);
        if (axis < 2)
        {
            CHECK(output->currentRefDqA[axis] == 0.0f && output->currentFeedbackDqA[axis] == 0.0f);
            CHECK(output->voltageRawDqV[axis] == 0.0f && output->voltageAppliedDqV[axis] == 0.0f);
            CHECK(output->integralDqV[axis] == 0.0f);
        }
    }
    return true;
}

/** @brief 独立 double 公式从最终三相 duty 重建 dq，不调用生产变换。 */
static void reconstruct(const IfOutput *output, float bus, double voltage[2])
{
    const double alpha = bus * (2.0 * output->duty[0] - output->duty[1] - output->duty[2]) / 3.0;
    const double beta = bus * (output->duty[1] - output->duty[2]) / sqrt(3.0);
    const double angle = output->thetaUsedRad;

    voltage[0] = alpha * cos(angle) + beta * sin(angle);
    voltage[1] = -alpha * sin(angle) + beta * cos(angle);
}

/** @brief V01/V02：零序投影、q 轴正号以及旋转坐标的一致性。 */
static bool check_projection(void)
{
    const float currents[4][3] = {{1.0f, -0.5f, -0.5f},
                                  {1.2f, -0.3f, -0.3f},
                                  {0.0f, 0.8660254038f, -0.8660254038f},
                                  {0.0f, 0.8660254038f, -0.8660254038f}};
    const IfConfig config = test_config();
    int vector;

    for (vector = 0; vector < 4; ++vector)
    {
        IfController controller = {0};
        IfInput input = test_input();
        IfOutput output;

        memcpy(input.phaseCurrentA, currents[vector], sizeof(input.phaseCurrentA));
        input.startAngleRad = vector == 3 ? (float)(TEST_PI / 2.0) : 0.0f;
        CHECK(if_init(&controller, &config) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(fabsf(output.currentFeedbackDqA[0] - (vector == 2 ? 0.0f : 1.0f)) < 1.0e-5f);
        CHECK(fabsf(output.currentFeedbackDqA[1] - (vector == 2 ? 1.0f : 0.0f)) < 1.0e-5f);
        CHECK(fabsf(output.voltageRawDqV[0] + output.currentFeedbackDqA[0]) < 1.0e-5f);
        CHECK(fabsf(output.voltageRawDqV[1] + output.currentFeedbackDqA[1]) < 1.0e-5f);
    }
    return true;
}

/** @brief V03～V05：真实入口的圆盘、欧氏限速、首拍相位和反向过零。 */
static bool check_reference(void)
{
    IfConfig config = test_config();
    IfController controller = {0};
    IfInput input = test_input();
    IfOutput output;
    float nextAngle;

    config.currentLimitA = 2.0f;
    config.currentSlewAps = 10.0f;
    config.frequencySlewHzps = 10.0f;
    input.currentTargetDqA[0] = 3.0f;
    input.currentTargetDqA[1] = 4.0f;
    input.frequencyTargetHz = 1.0f;
    CHECK(if_init(&controller, &config) == IF_OK);
    CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
    CHECK(fabsf(output.currentRefDqA[0] - 0.06f) < 1.0e-5f);
    CHECK(fabsf(output.currentRefDqA[1] - 0.08f) < 1.0e-5f);
    CHECK((output.flags & IF_FLAG_CURRENT_LIMITED) != 0u);
    CHECK((output.flags & IF_FLAG_CURRENT_SLEW) != 0u);
    CHECK(output.thetaUsedRad == 0.0f && fabsf(output.frequencyRefHz - 0.1f) < 1.0e-6f);
    CHECK(fabs(output.deltaThetaRad - 0.0062831853) < 1.0e-7);
    nextAngle = output.deltaThetaRad;
    input.startAngleRad = NAN;
    input.frequencyTargetHz = 0.05f;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(fabsf(output.thetaUsedRad - nextAngle) < 1.0e-6f);
    CHECK(output.frequencyRefHz == 0.05f);
    input.frequencyTargetHz = -1.0f;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(output.frequencyRefHz == 0.0f && output.deltaThetaRad == 0.0f);
    CHECK((output.flags & IF_FLAG_FREQUENCY_SLEW) != 0u && output.currentRefDqA[0] > 0.0f);
    nextAngle = output.thetaUsedRad;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(fabsf(output.frequencyRefHz + 0.1f) < 1.0e-6f && output.currentRefDqA[0] > 0.0f);
    CHECK(output.thetaUsedRad == nextAngle && output.deltaThetaRad < 0.0f);
    input.frequencyTargetHz = -100.0f;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK((output.flags & IF_FLAG_FREQUENCY_LIMITED) != 0u);
    return true;
}

/** @brief V06/V07：物理电压归一化、圆形边界和裕量均经过完整 IF 入口。 */
static bool check_voltage(void)
{
    IfConfig config = test_config();
    IfController controller = {0};
    IfInput input = test_input();
    IfOutput output;
    int margin;

    input.currentTargetDqA[0] = 12.0f;
    CHECK(if_init(&controller, &config) == IF_OK);
    CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
    CHECK(fabsf(output.duty[0] - 0.875f) < 2.0e-6f);
    CHECK(fabsf(output.duty[1] - 0.125f) < 2.0e-6f);
    CHECK(fabsf(output.duty[2] - 0.125f) < 2.0e-6f);
    CHECK(fabsf(output.voltageAppliedDqV[0] - 12.0f) < 1.0e-4f);
    for (margin = 0; margin < 2; ++margin)
    {
        IfController boundary = {0};
        double voltage[2];

        config.dutyMargin = margin == 0 ? 0.05f : 0.0f;
        input.currentTargetDqA[0] = 20.0f;
        input.startAngleRad = (float)(TEST_PI / 6.0);
        CHECK(if_init(&boundary, &config) == IF_OK);
        CHECK(if_update(&boundary, &input, &output) == IF_OK && output.outputValid);
        CHECK((output.flags & IF_FLAG_VOLTAGE_LIMITED) != 0u);
        CHECK(fabsf(output.duty[0] - (1.0f - config.dutyMargin)) < 2.0e-6f);
        CHECK(fabsf(output.duty[1] - 0.5f) < 2.0e-6f);
        CHECK(fabsf(output.duty[2] - config.dutyMargin) < 2.0e-6f);
        CHECK(fabs(output.voltageLimitV - (1.0 - 2.0 * config.dutyMargin) * 24.0 / sqrt(3.0)) <
              1.0e-4);
        reconstruct(&output, input.busVoltageV, voltage);
        CHECK(fabs(voltage[0] - output.voltageLimitV) < 1.0e-4 && fabs(voltage[1]) < 1.0e-4);
    }
    return true;
}

/** @brief V08：两轴积分只按最终 duty 电压更新一次，不由积分硬限幅替代回算。 */
static bool check_tracking(void)
{
    IfConfig config = test_config();
    IfController controller = {0};
    IfInput input = test_input();
    IfOutput output;
    double voltage[2];
    int axis;

    config.voltageLimitV = 1.0f;
    config.piD = (IfPiConfig){1.0f, 10.0f, 2.0f, 1.0f};
    config.piQ = config.piD;
    input.currentTargetDqA[0] = 1.0f;
    input.currentTargetDqA[1] = 1.0f;
    CHECK(if_init(&controller, &config) == IF_OK);
    CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
    reconstruct(&output, input.busVoltageV, voltage);
    for (axis = 0; axis < 2; ++axis)
    {
        CHECK(output.voltageRawDqV[axis] == 1.0f);
        CHECK(fabs(voltage[axis] - 1.0 / sqrt(2.0)) < 1.0e-5);
        CHECK(fabsf(output.integralDqV[axis] - 0.041421356f) < 1.0e-5f);
        CHECK(fabs(output.integralDqV[axis] - 0.1 * (1.0 + 2.0 * (voltage[axis] - 1.0))) < 1.0e-5);
    }
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(fabsf(output.voltageRawDqV[0] - 1.041421356f) < 1.0e-5f);
    /* 不同轴增益必须各自生效，不能把 d 轴配置复制成两套相同调节器。 */
    input.action = IF_ACTION_DISABLE;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    config.voltageLimitV = 10.0f;
    config.piQ = (IfPiConfig){2.0f, 5.0f, 1.0f, 1.0f};
    CHECK(if_init(&controller, &config) == IF_OK);
    input.action = IF_ACTION_START;
    input.currentTargetDqA[0] = 0.2f;
    input.currentTargetDqA[1] = -0.3f;
    CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
    CHECK(fabsf(output.voltageRawDqV[0] - 0.2f) < 1.0e-5f);
    CHECK(fabsf(output.voltageRawDqV[1] + 0.6f) < 1.0e-5f);
    CHECK(fabsf(output.integralDqV[0] - 0.02f) < 1.0e-5f);
    CHECK(fabsf(output.integralDqV[1] + 0.015f) < 1.0e-5f);
    return true;
}

/** @brief V09/V10：停机终点不再激励，固定方向保持与立即禁用相互独立。 */
static bool check_lifecycle(void)
{
    IfConfig config = test_config();
    IfController controller = {0};
    IfInput input = test_input();
    IfOutput output;
    const float expectedFrequency[3] = {0.1f, 0.0f, 0.0f};
    const float expectedCurrent[3] = {0.2f, 0.2f, 0.1f};
    float angle;
    int tick;

    config.currentSlewAps = 10.0f;
    config.frequencySlewHzps = 10.0f;
    input.currentTargetDqA[0] = 0.2f;
    input.frequencyTargetHz = 0.2f;
    CHECK(if_init(&controller, &config) == IF_OK);
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    input.action = IF_ACTION_STOP;
    input.currentTargetDqA[0] = NAN;
    input.frequencyTargetHz = NAN;
    for (tick = 0; tick < 3; ++tick)
    {
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(output.state == IF_STATE_STOPPING);
        CHECK(fabsf(output.frequencyRefHz - expectedFrequency[tick]) < 1.0e-6f);
        CHECK(fabsf(output.currentRefDqA[0] - expectedCurrent[tick]) < 1.0e-6f);
        input.action = IF_ACTION_START;
    }
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(check_invalid(&output, IF_STATE_STOPPED, IF_OK));
    input.action = IF_ACTION_KEEP;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(check_invalid(&output, IF_STATE_STOPPED, IF_OK));
    input = test_input();
    input.currentTargetDqA[0] = 1.0f;
    input.startAngleRad = 0.7f;
    for (tick = 0; tick < 200; ++tick)
    {
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(output.thetaUsedRad == 0.7f && output.deltaThetaRad == 0.0f);
    }
    input.action = IF_ACTION_DISABLE;
    input.sampleValid = false;
    input.phaseCurrentA[0] = NAN;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(check_invalid(&output, IF_STATE_STOPPED, IF_OK));
    input = test_input();
    input.frequencyTargetHz = 1.0f;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    angle = output.thetaUsedRad + output.deltaThetaRad;
    input.action = IF_ACTION_START;
    input.startAngleRad = 2.0f;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    CHECK(fabsf(output.thetaUsedRad - angle) < 1.0e-5f);
    return true;
}

/** @brief 检查故障优先级、锁存、NULL 原子性和失败后显式恢复。 */
static bool check_errors(void)
{
    const IfConfig config = test_config();
    const IfStatus expected[] = {IF_ERR_SAMPLE, IF_ERR_NUMBER, IF_ERR_VBUS,
                                 IF_ERR_RANGE,  IF_ERR_ACTION, IF_ERR_CALC};
    int scenario;

    for (scenario = 0; scenario < 6; ++scenario)
    {
        IfController controller = {0};
        IfInput input = test_input();
        IfOutput output;

        CHECK(if_init(&controller, &config) == IF_OK);
        if (scenario == 0)
        {
            input.sampleValid = false;
            input.phaseCurrentA[0] = NAN;
        }
        else if (scenario == 1)
        {
            input.phaseCurrentA[1] = INFINITY;
            input.busVoltageV = 0.0f;
        }
        else if (scenario == 2)
        {
            input.busVoltageV = 0.0f;
            input.startAngleRad = -1.0f;
        }
        else if (scenario == 3)
        {
            input.startAngleRad = (float)(2.0 * TEST_PI);
        }
        else if (scenario == 4)
        {
            input.action = (IfAction)99;
            input.sampleValid = false;
        }
        else
        {
            input.phaseCurrentA[0] = FLT_MAX;
            input.phaseCurrentA[1] = -FLT_MAX;
            input.phaseCurrentA[2] = -FLT_MAX;
        }
        CHECK(if_update(&controller, &input, &output) == expected[scenario]);
        CHECK(check_invalid(&output, IF_STATE_FAULT, expected[scenario]));
        input = test_input();
        input.action = IF_ACTION_DISABLE;
        CHECK(if_update(&controller, &input, &output) == expected[scenario]);
        CHECK(check_invalid(&output, IF_STATE_FAULT, expected[scenario]));
        CHECK(if_reset(&controller) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        CHECK(check_invalid(&output, IF_STATE_STOPPED, IF_OK));
        input.action = IF_ACTION_START;
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(output.thetaUsedRad == 0.0f && output.integralDqV[0] == 0.0f);
    }
    /* V11 使用已经积累积分的运行实例，后续 START 也不能绕开锁存故障。 */
    {
        IfController controller = {0};
        IfConfig integralConfig = test_config();
        IfInput input = test_input();
        IfOutput output;

        integralConfig.piD = (IfPiConfig){1.0f, 10.0f, 1.0f, 20.0f};
        integralConfig.piQ = integralConfig.piD;
        input.currentTargetDqA[0] = 1.0f;
        CHECK(if_init(&controller, &integralConfig) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        CHECK(output.integralDqV[0] > 0.0f);
        input.phaseCurrentA[0] = NAN;
        CHECK(if_update(&controller, &input, &output) == IF_ERR_NUMBER);
        CHECK(check_invalid(&output, IF_STATE_FAULT, IF_ERR_NUMBER));
        input.phaseCurrentA[0] = 0.0f;
        CHECK(if_update(&controller, &input, &output) == IF_ERR_NUMBER);
        CHECK(if_reset(&controller) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(output.voltageRawDqV[0] == 1.0f);
    }
    /* 第一轴跟踪成功后第二轴计算溢出，不能发布半完成的正常输出。 */
    {
        IfController controller = {0};
        IfConfig extreme = test_config();
        IfInput input = test_input();
        IfOutput output;

        extreme.piQ = (IfPiConfig){1.0f, FLT_MAX, FLT_MIN, 20.0f};
        input.currentTargetDqA[0] = 1.0f;
        input.currentTargetDqA[1] = 2.0f;
        CHECK(if_init(&controller, &extreme) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_ERR_CALC);
        CHECK(check_invalid(&output, IF_STATE_FAULT, IF_ERR_CALC));
    }
    /* 指针失败只覆盖可写输出，不修改运行实例。 */
    {
        IfController controller = {0};
        IfController before;
        IfInput input = test_input();
        IfOutput output;

        CHECK(if_update(&controller, &input, &output) == IF_ERR_STATE);
        CHECK(check_invalid(&output, IF_STATE_UNINITIALIZED, IF_ERR_STATE));
        CHECK(if_reset(&controller) == IF_ERR_STATE);
        CHECK(if_init(&controller, &config) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        memcpy(&before, &controller, sizeof(before));
        CHECK(if_update(&controller, NULL, &output) == IF_ERR_NULL);
        CHECK(check_invalid(&output, IF_STATE_RUNNING, IF_ERR_NULL));
        CHECK(if_update(&controller, &input, NULL) == IF_ERR_NULL);
        CHECK(memcmp(&before, &controller, sizeof(before)) == 0);
        CHECK(if_update(NULL, &input, &output) == IF_ERR_NULL);
        CHECK(check_invalid(&output, IF_STATE_UNINITIALIZED, IF_ERR_NULL));
        CHECK(if_init(NULL, &config) == IF_ERR_NULL && if_reset(NULL) == IF_ERR_NULL);
        CHECK(if_init(&controller, NULL) == IF_ERR_NULL);
        CHECK(if_reset(&controller) == IF_ERR_STATE &&
              if_init(&controller, &config) == IF_ERR_STATE);
        CHECK(memcmp(&before, &controller, sizeof(before)) == 0);
    }
    return true;
}

/** @brief V12：无效配置不能部分应用；覆盖乘积、下溢和不可推进斜坡。 */
static bool check_config(void)
{
    int scenario;

    for (scenario = 0; scenario < 12; ++scenario)
    {
        IfConfig config = test_config();
        IfController controller = {0};
        IfController before;

        CHECK(if_init(&controller, &config) == IF_OK);
        memcpy(&before, &controller, sizeof(before));
        switch (scenario)
        {
            case 0:
                config.periodS = 0.0f;
                break;
            case 1:
                config.currentLimitA = -1.0f;
                break;
            case 2:
                config.dutyMargin = 0.5f;
                break;
            case 3:
                config.piD = (IfPiConfig){1.0f, 1000.0f, 2.0f, 10.0f};
                break;
            case 4:
                config.currentSlewAps = FLT_MIN;
                break;
            case 5:
                config.periodS = FLT_MIN;
                break;
            case 6:
                config.periodS = 2.0f;
                config.frequencyLimitHz = 0.1f;
                config.currentSlewAps = FLT_MAX;
                break;
            case 7:
                config.frequencyLimitHz = 50.0f;
                break;
            case 8:
                config.piQ.kp = INFINITY;
                break;
            case 9:
                config.piQ.ki = 1.0f;
                break;
            case 10:
                config.piQ.integralLimitV = 21.0f;
                break;
            default:
                config.piD = (IfPiConfig){1.0f, FLT_MIN, FLT_MIN, 1.0f};
                break;
        }
        CHECK(if_init(&controller, &config) == IF_ERR_CONFIG);
        CHECK(memcmp(&before, &controller, sizeof(before)) == 0);
    }
    /* 巨大的有限目标仍能径向限幅；纯零序大电流不在投影时溢出。 */
    {
        IfController controller = {0};
        IfConfig config = test_config();
        IfInput input = test_input();
        IfOutput output;

        config.currentLimitA = 2.0f;
        input.currentTargetDqA[0] = FLT_MAX;
        input.currentTargetDqA[1] = FLT_MAX;
        input.phaseCurrentA[0] = FLT_MAX;
        input.phaseCurrentA[1] = FLT_MAX;
        input.phaseCurrentA[2] = FLT_MAX;
        CHECK(if_init(&controller, &config) == IF_OK);
        CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
        CHECK(output.currentFeedbackDqA[0] == 0.0f && output.currentFeedbackDqA[1] == 0.0f);
        CHECK(fabsf(output.currentRefDqA[0] - sqrtf(2.0f)) < 1.0e-5f);
    }
    return true;
}

/** @brief 在全扇区和两轴上独立核对完整入口的电压圆盘、duty 及施加电压。 */
static bool check_sweep(void)
{
    const float buses[] = {6.0f, 24.0f, 60.0f};
    const float margins[] = {0.0f, 0.05f, 0.2f};
    const float targets[][2] = {{0.0f, 0.0f}, {1.2f, -0.8f}, {16.0f, 12.0f}, {-12.0f, -16.0f}};
    int bus;
    int margin;
    int target;
    int angle;

    for (bus = 0; bus < 3; ++bus)
    {
        for (margin = 0; margin < 3; ++margin)
        {
            for (target = 0; target < 4; ++target)
            {
                for (angle = 0; angle < 360; ++angle)
                {
                    IfConfig config = test_config();
                    IfController controller = {0};
                    IfInput input = test_input();
                    IfOutput output;
                    double voltage[2];
                    const double norm = hypot(targets[target][0], targets[target][1]);
                    double cap;
                    double ratio;
                    int axis;

                    config.dutyMargin = margins[margin];
                    input.busVoltageV = buses[bus];
                    input.startAngleRad = (float)(angle * TEST_PI / 180.0);
                    input.currentTargetDqA[0] = targets[target][0];
                    input.currentTargetDqA[1] = targets[target][1];
                    cap = fmin(config.voltageLimitV,
                               (1.0 - 2.0 * config.dutyMargin) * input.busVoltageV / sqrt(3.0));
                    ratio = norm > cap ? cap / norm : 1.0;
                    CHECK(if_init(&controller, &config) == IF_OK);
                    CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
                    reconstruct(&output, input.busVoltageV, voltage);
                    for (axis = 0; axis < 2; ++axis)
                    {
                        CHECK(fabs(voltage[axis] - targets[target][axis] * ratio) < 1.0e-4);
                        CHECK(fabs(voltage[axis] - output.voltageAppliedDqV[axis]) < 1.0e-4);
                    }
                    for (axis = 0; axis < 3; ++axis)
                    {
                        CHECK(output.duty[axis] >= config.dutyMargin);
                        CHECK(output.duty[axis] <= 1.0f - config.dutyMargin);
                    }
                    CHECK((output.flags & ~((uint32_t)63u)) == 0u);
                }
            }
        }
    }
    return true;
}

/** @brief 基础长期检查：正反旋转、环绕及低频累计，独立参考只读公开输出。 */
static bool check_phase(void)
{
    const float frequencies[] = {0.0f, 0.0001f, -0.0001f, 10.0f, -10.0f};
    int scenario;
    double worst = 0.0;

    for (scenario = 0; scenario < 5; ++scenario)
    {
        IfConfig config = test_config();
        IfController controller = {0};
        IfInput input = test_input();
        IfOutput output;
        double reference;
        int tick;

        config.periodS = 0.0001f;
        config.frequencySlewHzps = 1000000.0f;
        input.frequencyTargetHz = frequencies[scenario];
        input.startAngleRad = scenario == 2 ? 0.0f : 5.9f;
        reference = input.startAngleRad;
        CHECK(if_init(&controller, &config) == IF_OK);
        for (tick = 0; tick < 100000; ++tick)
        {
            double error;

            CHECK(if_update(&controller, &input, &output) == IF_OK && output.outputValid);
            CHECK(output.thetaUsedRad >= 0.0f && output.thetaUsedRad < (float)(2.0 * TEST_PI));
            error = fabs(remainder(output.thetaUsedRad - reference, 2.0 * TEST_PI));
            worst = fmax(worst, error);
            CHECK(error <= 0.005);
            reference = fmod(reference + 2.0 * TEST_PI * output.frequencyRefHz * config.periodS +
                                 2.0 * TEST_PI,
                             2.0 * TEST_PI);
            input.action = IF_ACTION_KEEP;
        }
        if (frequencies[scenario] == 0.0f)
        {
            CHECK(output.thetaUsedRad == input.startAngleRad);
        }
        else
        {
            CHECK(output.thetaUsedRad != input.startAngleRad);
        }
    }
    printf("phase: 5 x 100000 ticks, max circular error %.9g rad\n", worst);
    return true;
}

/** @brief 运行真实入口的确定向量与完整链路验证。 */
int main(void)
{
    if (!check_projection() || !check_reference() || !check_voltage() || !check_tracking() ||
        !check_lifecycle() || !check_errors() || !check_config() || !check_sweep() ||
        !check_phase())
    {
        return EXIT_FAILURE;
    }
    puts("IF control: deterministic vectors and 12960 full-chain modulation cases passed");
    return EXIT_SUCCESS;
}
