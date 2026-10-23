/**
 * @file test_if_rl.c
 * @brief 最终 duty 驱动独立 R-L 模型，验证强拉、D/Q 交接及饱和恢复。
 * @author HU JIAXUAN
 */
#include "if_controller.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_PI (3.14159265358979323846)
#define CHECK(condition)                                                                           \
    do                                                                                             \
    {                                                                                              \
        if (!(condition))                                                                          \
        {                                                                                          \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);                        \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

/** @brief 无机械运动及反电动势，R=1 ohm、L=1 mH 的独立对象。 */
typedef struct
{
    double alphaA;
    double betaA;
} RlPlant;

static IfConfig model_config(float cap, float angle);
static bool model_tick(IfController *controller, IfInput *input, IfOutput *output, RlPlant *plant,
                       double current[2]);
static bool check_normal(float angle, int sign);
static bool check_saturation(float angle, int sign);

/** @brief 50 拍对齐缓升、150 拍保持，随后验证同一物理电流方向交接。 */
static IfConfig model_config(float cap, float angle)
{
    const IfConfig config = {.periodS = 0.0001f,
                             .currentLimitA = 2.0f,
                             .voltageLimitV = cap,
                             .busMinV = 1.0f,
                             .dutyMargin = 0.05f,
                             .piD = {1.0f, 1000.0f},
                             .piQ = {1.0f, 1000.0f},
                             .alignAngleRad = angle,
                             .alignCurrentA = 1.0f,
                             .alignRampS = 0.005f,
                             .alignHoldS = 0.015f,
                             .frequencyRampS = 0.005f};
    return config;
}

/** @brief 只由最终 duty 与母线重建施加电压，不使用生产变换或电压观测。 */
static bool model_tick(IfController *controller, IfInput *input, IfOutput *output, RlPlant *plant,
                       double current[2])
{
    const double decay = exp(-(double)controller->config.periodS / 0.001);
    double alphaV, betaV;
    int phase;
    input->phaseCurrentA[0] = (float)plant->alphaA;
    input->phaseCurrentA[1] = (float)(-plant->alphaA / 2.0 + sqrt(3.0) * plant->betaA / 2.0);
    input->phaseCurrentA[2] = (float)(-plant->alphaA / 2.0 - sqrt(3.0) * plant->betaA / 2.0);
    CHECK(if_update(controller, input, output) == IF_OK && output->outputValid);
    for (phase = 0; phase < 3; ++phase)
    {
        CHECK(output->duty[phase] >= 0.05f && output->duty[phase] <= 0.95f);
    }
    alphaV = input->busVoltageV * (2.0 * output->duty[0] - output->duty[1] - output->duty[2]) / 3.0;
    betaV = input->busVoltageV * (output->duty[1] - output->duty[2]) / sqrt(3.0);
    plant->alphaA = decay * plant->alphaA + (1.0 - decay) * alphaV;
    plant->betaA = decay * plant->betaA + (1.0 - decay) * betaV;
    current[0] = plant->alphaA * cos(output->thetaRad) + plant->betaA * sin(output->thetaRad);
    current[1] = plant->betaA * cos(output->thetaRad) - plant->alphaA * sin(output->thetaRad);
    return true;
}

/** @brief 真实启动后保持正/负 Q 轴目标，并验证降母线后的跟踪。 */
static bool check_normal(float angle, int sign)
{
    const IfConfig config = model_config(10.0f, angle);
    IfController controller = {0};
    IfInput input = {0};
    IfOutput output;
    RlPlant plant = {0.0, 0.0};
    double current[2], peak = 0.0, error = 0.0;
    int tick, neutralCount = 0;
    input.enable = true;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    input.currentA = (float)sign;
    input.frequencyHz = 5.0f * sign;
    CHECK(if_init(&controller, &config) == IF_OK);
    for (tick = 0; tick < 1000; ++tick)
    {
        if (tick == 700)
        {
            input.busVoltageV = 6.0f;
        }
        CHECK(model_tick(&controller, &input, &output, &plant, current));
        peak = fmax(peak, hypot(plant.alphaA, plant.betaA));
        CHECK(peak <= 1.05);
        if (output.state == IF_STATE_HANDOFF)
        {
            ++neutralCount;
            CHECK(output.duty[0] == 0.5f && output.duty[1] == 0.5f && output.duty[2] == 0.5f);
        }
        if (tick >= 100 && output.state == IF_STATE_ALIGN)
        {
            CHECK(fabs(current[0] - 1.0) <= 0.02 && fabs(current[1]) <= 0.01);
        }
        if ((tick >= 350 && tick < 700) || tick >= 800)
        {
            CHECK(output.state == IF_STATE_RUNNING);
            error = fmax(error, fabs(current[1] - sign));
            CHECK(fabs(current[1] - sign) <= 0.02 && fabs(current[0]) <= 0.01);
        }
    }
    CHECK(neutralCount == 1);
    printf("IF R-L normal angle %.7g sign %d: peak %.9g A, error %.9g A\n", angle, sign, peak,
           error);
    return true;
}

/** @brief 持续限压后撤销运行电流，验证积分界与恢复，不跳过强拉。 */
static bool check_saturation(float angle, int sign)
{
    const IfConfig config = model_config(0.5f, angle);
    IfController controller = {0};
    IfInput input = {0};
    IfOutput output;
    RlPlant plant = {0.0, 0.0};
    double current[2];
    int tick;
    input.enable = true;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    input.currentA = (float)sign;
    CHECK(if_init(&controller, &config) == IF_OK);
    for (tick = 0; tick < 1500; ++tick)
    {
        if (tick == 1000)
        {
            input.currentA = 0.0f;
        }
        CHECK(model_tick(&controller, &input, &output, &plant, current));
        CHECK(fabsf(controller.pi[0].integral) <= 0.5f && fabsf(controller.pi[1].integral) <= 0.5f);
        if (tick >= 900 && tick < 1000)
        {
            CHECK(output.voltageLimited && output.state == IF_STATE_RUNNING);
            CHECK(fabs(current[1] - sign * 0.5) <= 0.02 && fabs(current[0]) <= 0.01);
        }
    }
    CHECK(fabs(current[0]) <= 0.02 && fabs(current[1]) <= 0.02);
    printf("IF R-L saturation angle %.7g sign %d: residual [%.9g, %.9g] A\n", angle, sign,
           current[0], current[1]);
    return true;
}

/** @brief 在两个角度、两个电流符号下执行正常及限压电气闭环。 */
int main(void)
{
    int angle, sign;
    for (angle = 0; angle < 2; ++angle)
    {
        for (sign = -1; sign <= 1; sign += 2)
        {
            const float radians = angle == 0 ? 0.0f : (float)(TEST_PI / 3.0);
            if (!check_normal(radians, sign) || !check_saturation(radians, sign))
            {
                return EXIT_FAILURE;
            }
        }
    }
    return EXIT_SUCCESS;
}
