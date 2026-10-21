/**
 * @file test_if_rl.c
 * @brief 从最终 duty 独立推进 R-L 模型，检验真实 IF 的两轴电流闭环。
 * @author HU JIAXUAN
 */

#include "if_controller.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_PI (3.14159265358979323846) /**< 模型独立双精度圆周率。 */
#define CHECK(condition)                                                                           \
    do                                                                                             \
    {                                                                                              \
        if (!(condition))                                                                          \
        {                                                                                          \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);                        \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

/** @brief 无反电动势、静止 alpha/beta 电气对象，R=1 ohm、L=1 mH。 */
typedef struct
{
    double alphaA; /**< alpha 电流，A。 */
    double betaA;  /**< beta 电流，A。 */
    float periodS; /**< 测试方持有的固定周期，s。 */
} RlPlant;

static IfConfig model_config(bool saturated);
static bool model_tick(IfController *controller, IfInput *input, IfOutput *output, RlPlant *plant,
                       double currentDq[2]);
static bool check_normal(int axis, float angle);
static bool check_saturation(int axis, float angle);

/** @brief 使用 README 的固定验证参数，不使用被测实现计算模型系数。 */
static IfConfig model_config(bool saturated)
{
    const float cap = saturated ? 0.5f : 10.0f;
    const IfPiConfig pi = {1.0f, 1000.0f, 1.0f, cap};
    const IfConfig config = {0.0001f, 2.0f, 10.0f, 10000.0f, 1000.0f, cap, 1.0f, 0.05f, pi, pi};

    return config;
}

/** @brief 采样上拍模型电流、运行真实控制器，再仅从 duty 和母线驱动独立模型。 */
static bool model_tick(IfController *controller, IfInput *input, IfOutput *output, RlPlant *plant,
                       double currentDq[2])
{
    double appliedAlpha;
    double appliedBeta;
    double decay;
    int leg;

    input->phaseCurrentA[0] = (float)plant->alphaA;
    input->phaseCurrentA[1] = (float)(-plant->alphaA / 2.0 + sqrt(3.0) * plant->betaA / 2.0);
    input->phaseCurrentA[2] = (float)(-plant->alphaA / 2.0 - sqrt(3.0) * plant->betaA / 2.0);
    CHECK(if_update(controller, input, output) == IF_OK && output->outputValid);
    CHECK(output->state == IF_STATE_RUNNING && output->frequencyRefHz == 0.0f);
    for (leg = 0; leg < 3; ++leg)
    {
        CHECK(isfinite(output->duty[leg]));
        CHECK(output->duty[leg] >= 0.05f && output->duty[leg] <= 0.95f);
    }
    /* 只读最终 duty 与实际输入母线，不使用 IF 的电压观测量或生产变换。 */
    appliedAlpha =
        input->busVoltageV * (2.0 * output->duty[0] - output->duty[1] - output->duty[2]) / 3.0;
    appliedBeta = input->busVoltageV * (output->duty[1] - output->duty[2]) / sqrt(3.0);
    decay = exp(-(double)plant->periodS / 0.001);
    plant->alphaA = decay * plant->alphaA + (1.0 - decay) * appliedAlpha;
    plant->betaA = decay * plant->betaA + (1.0 - decay) * appliedBeta;
    currentDq[0] =
        plant->alphaA * cos(input->startAngleRad) + plant->betaA * sin(input->startAngleRad);
    currentDq[1] =
        -plant->alphaA * sin(input->startAngleRad) + plant->betaA * cos(input->startAngleRad);
    input->action = IF_ACTION_KEEP;
    return true;
}

/** @brief 两个固定角度分别激励两轴，验证启动、交叉轴误差和母线 24→6 V。 */
static bool check_normal(int axis, float angle)
{
    const IfConfig config = model_config(false);
    IfController controller = {0};
    IfInput input = {0};
    IfOutput output;
    RlPlant plant = {0.0, 0.0, config.periodS};
    double current[2];
    double peak = 0.0;
    double error = 0.0;
    int tick;

    input.action = IF_ACTION_START;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    input.startAngleRad = angle;
    input.currentTargetDqA[axis] = 1.0f;
    CHECK(if_init(&controller, &config) == IF_OK);
    for (tick = 0; tick < 700; ++tick)
    {
        if (tick == 500)
        {
            input.busVoltageV = 6.0f;
        }
        CHECK(model_tick(&controller, &input, &output, &plant, current));
        peak = fmax(peak, current[axis]);
        CHECK(peak <= 1.05);
        if ((tick >= 100 && tick < 500) || tick >= 600)
        {
            error = fmax(error, fabs(current[axis] - 1.0));
            CHECK(fabs(current[axis] - 1.0) <= 0.02);
            CHECK(fabs(current[1 - axis]) <= 0.01);
        }
    }
    printf("R-L normal: axis %d angle %.7g, peak %.9g A, max settled error %.9g A\n", axis, angle,
           peak, error);
    return true;
}

/** @brief 限压 0.5 V 持续 100 ms 后撤销目标，验证饱和电流、积分界和恢复。 */
static bool check_saturation(int axis, float angle)
{
    const IfConfig config = model_config(true);
    IfController controller = {0};
    IfInput input = {0};
    IfOutput output;
    RlPlant plant = {0.0, 0.0, config.periodS};
    double current[2];
    int tick;
    int component;

    input.action = IF_ACTION_START;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    input.startAngleRad = angle;
    input.currentTargetDqA[axis] = 1.0f;
    CHECK(if_init(&controller, &config) == IF_OK);
    for (tick = 0; tick < 1500; ++tick)
    {
        if (tick == 1000)
        {
            input.currentTargetDqA[axis] = 0.0f;
        }
        CHECK(model_tick(&controller, &input, &output, &plant, current));
        for (component = 0; component < 2; ++component)
        {
            CHECK(fabsf(output.integralDqV[component]) <= 0.5f);
        }
        if (tick < 1000)
        {
            CHECK((output.flags & IF_FLAG_VOLTAGE_LIMITED) != 0u);
        }
        if (tick >= 900 && tick < 1000)
        {
            CHECK(fabs(current[axis] - 0.5) <= 0.02 && fabs(current[1 - axis]) <= 0.01);
        }
    }
    CHECK(fabs(current[0]) <= 0.02 && fabs(current[1]) <= 0.02);
    printf("R-L saturation: axis %d angle %.7g, residual [%.9g, %.9g] A\n", axis, angle, current[0],
           current[1]);
    return true;
}

/** @brief 每种初角分别执行 d/q 正常与饱和模型，不共享生产变换或控制公式。 */
int main(void)
{
    int axis;
    int angle;

    for (axis = 0; axis < 2; ++axis)
    {
        for (angle = 0; angle < 2; ++angle)
        {
            const float radians = angle == 0 ? 0.0f : (float)(TEST_PI / 3.0);

            if (!check_normal(axis, radians) || !check_saturation(axis, radians))
            {
                return EXIT_FAILURE;
            }
        }
    }
    return EXIT_SUCCESS;
}
