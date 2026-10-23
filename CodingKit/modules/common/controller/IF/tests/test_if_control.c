/**
 * @file test_if_control.c
 * @brief 实际 C 验证 D 轴强拉、交接、相位、限压与错误处理。
 * @author HU JIAXUAN
 */
#include "if_controller.h"

#include <float.h>
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

static IfConfig test_config(void);
static IfInput test_input(void);
static bool enter_run(IfController *controller, IfInput *input, IfOutput *output);
static bool check_start(void);
static bool check_errors(void);
static bool check_numeric(void);
static bool check_phase(void);

/** @brief 小整数拍数便于独立核对启动顺序。 */
static IfConfig test_config(void)
{
    const IfConfig config = {.periodS = 0.01f,
                             .currentLimitA = 4.0f,
                             .voltageLimitV = 20.0f,
                             .busMinV = 1.0f,
                             .dutyMargin = 0.05f,
                             .piD = {1.0f, 10.0f},
                             .piQ = {1.0f, 10.0f},
                             .alignAngleRad = 0.7f,
                             .alignCurrentA = 2.0f,
                             .alignRampS = 0.02f,
                             .alignHoldS = 0.02f,
                             .frequencyRampS = 0.03f};
    return config;
}

/** @brief 默认零反馈、有电流和频率给定的有效采样。 */
static IfInput test_input(void)
{
    IfInput input = {0};
    input.enable = true;
    input.sampleValid = true;
    input.busVoltageV = 24.0f;
    input.currentA = 3.0f;
    input.frequencyHz = 1.0f;
    return input;
}

/** @brief 通过真实入口推进启动，不改写控制器内部阶段。 */
static bool enter_run(IfController *controller, IfInput *input, IfOutput *output)
{
    unsigned count;
    for (count = 0; count < 20u; ++count)
    {
        CHECK(if_update(controller, input, output) == IF_OK && output->outputValid);
        if (output->state == IF_STATE_RUNNING)
        {
            return true;
        }
    }
    CHECK(false);
}

/** @brief 核对四拍对齐、一拍零电压及正负电流的 90 度交接。 */
static bool check_start(void)
{
    int sign;
    for (sign = -1; sign <= 1; sign += 2)
    {
        const IfConfig config = test_config();
        IfController controller = {0};
        IfInput input = test_input();
        IfOutput output;
        int tick;
        input.currentA *= (float)sign;
        input.frequencyHz *= (float)sign;
        CHECK(if_init(&controller, &config) == IF_OK);
        for (tick = 0; tick < 4; ++tick)
        {
            CHECK(if_update(&controller, &input, &output) == IF_OK);
            CHECK(output.outputValid && output.state == IF_STATE_ALIGN);
            CHECK(fabsf(output.currentRefDqA[0] - (tick == 0 ? 1.0f : 2.0f)) < 1e-6f);
            CHECK(output.currentRefDqA[1] == 0.0f && output.frequencyHz == 0.0f);
            CHECK(output.thetaRad == config.alignAngleRad);
        }
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        CHECK(output.state == IF_STATE_HANDOFF && output.outputValid);
        CHECK(output.duty[0] == 0.5f && output.duty[1] == 0.5f && output.duty[2] == 0.5f);
        CHECK(controller.pi[0].integral == 0.0f && controller.pi[1].integral == 0.0f);
        for (tick = 1; tick <= 3; ++tick)
        {
            CHECK(if_update(&controller, &input, &output) == IF_OK);
            CHECK(output.state == IF_STATE_RUNNING && output.outputValid);
            CHECK(fabsf(output.frequencyHz - (float)sign * (float)tick / 3.0f) < 1e-6f);
            CHECK(output.currentRefDqA[0] == 0.0f && output.currentRefDqA[1] == input.currentA);
            if (tick == 1)
            {
                double angle = config.alignAngleRad - sign * TEST_PI / 2.0 +
                               2.0 * TEST_PI * output.frequencyHz * config.periodS;
                angle = fmod(angle + 2.0 * TEST_PI, 2.0 * TEST_PI);
                CHECK(fabs(angle - output.thetaRad) < 1e-6);
            }
        }
        input.enable = false;
        input.sampleValid = false;
        input.busVoltageV = NAN;
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        CHECK(!output.outputValid && output.state == IF_STATE_STOPPED);
        input = test_input();
        CHECK(if_update(&controller, &input, &output) == IF_OK);
        CHECK(output.state == IF_STATE_ALIGN && output.currentRefDqA[0] == 1.0f);
        CHECK(if_reset(&controller) == IF_OK && controller.state == IF_STATE_STOPPED);
    }
    return true;
}

/** @brief 非法采样锁存错误，显式停止或复位后才允许重新对齐。 */
static bool check_errors(void)
{
    IfConfig config = test_config();
    IfController controller = {0};
    IfInput input = test_input();
    IfOutput output;
    CHECK(if_update(&controller, &input, &output) == IF_ERR_STATE);
    config.alignCurrentA = 0.0f;
    CHECK(if_init(&controller, &config) == IF_ERR_CONFIG);
    config = test_config();
    config.alignRampS = 1e30f;
    CHECK(if_init(&controller, &config) == IF_ERR_CONFIG);
    config = test_config();
    CHECK(if_init(&controller, &config) == IF_OK);
    input.sampleValid = false;
    CHECK(if_update(&controller, &input, &output) == IF_ERR_INPUT);
    CHECK(!output.outputValid && output.state == IF_STATE_FAULT);
    input.sampleValid = true;
    CHECK(if_update(&controller, &input, &output) == IF_ERR_INPUT);
    input.enable = false;
    CHECK(if_update(&controller, &input, &output) == IF_OK);
    input.enable = true;
    input.phaseCurrentA[0] = INFINITY;
    CHECK(if_update(&controller, &input, &output) == IF_ERR_INPUT);
    CHECK(if_reset(&controller) == IF_OK);
    input.phaseCurrentA[0] = 0.0f;
    input.busVoltageV = 0.5f;
    CHECK(if_update(&controller, &input, &output) == IF_ERR_INPUT);
    CHECK(if_update(NULL, &input, &output) == IF_ERR_NULL && !output.outputValid);
    CHECK(if_update(&controller, &input, NULL) == IF_ERR_NULL);
    return true;
}

/** @brief 独立 double 公式核对所有角度的两轴 PI、圆形限压和最终 duty。 */
static bool check_numeric(void)
{
    int busIndex, marginIndex, currentIndex, degree;
    unsigned cases = 0u;
    for (busIndex = 0; busIndex < 3; ++busIndex)
    {
        for (marginIndex = 0; marginIndex < 3; ++marginIndex)
        {
            for (currentIndex = 0; currentIndex < 3; ++currentIndex)
            {
                for (degree = 0; degree < 360; ++degree)
                {
                    IfConfig config = test_config();
                    IfController controller = {0};
                    IfInput input = test_input();
                    IfOutput output;
                    double phase[3], duty[3], p[2], integral[2], untracked[2], voltage[2];
                    double mean, beta, id, iq;
                    double cap, length, common;
                    int axis;
                    config.periodS = 0.0001f;
                    config.alignRampS = 0.0f;
                    config.alignHoldS = config.periodS;
                    config.frequencyRampS = 0.0f;
                    config.alignAngleRad = (float)(degree * TEST_PI / 180.0);
                    config.dutyMargin = 0.05f * marginIndex;
                    config.piD = (IfPiConfig){2.0f, 30.0f};
                    config.piQ = (IfPiConfig){3.0f, 20.0f};
                    input.busVoltageV = (float[]){6.0f, 24.0f, 48.0f}[busIndex];
                    input.frequencyHz = 0.0f;
                    input.currentA = (float[]){0.0f, 1.0f, 10.0f}[currentIndex];
                    input.phaseCurrentA[0] = 0.4f;
                    input.phaseCurrentA[1] = -0.3f;
                    input.phaseCurrentA[2] = -0.1f;
                    CHECK(if_init(&controller, &config) == IF_OK);
                    CHECK(enter_run(&controller, &input, &output));
                    mean = ((double)input.phaseCurrentA[0] + input.phaseCurrentA[1] +
                            input.phaseCurrentA[2]) /
                           3.0;
                    beta = (input.phaseCurrentA[1] - (double)input.phaseCurrentA[2]) / sqrt(3.0);
                    id = (input.phaseCurrentA[0] - mean) * cos(output.thetaRad) +
                         beta * sin(output.thetaRad);
                    iq = beta * cos(output.thetaRad) -
                         (input.phaseCurrentA[0] - mean) * sin(output.thetaRad);
                    cap = fmin(config.voltageLimitV,
                               (1.0 - 2.0 * config.dutyMargin) * input.busVoltageV / sqrt(3.0));
                    p[0] = -id * config.piD.kp;
                    p[1] = (fmin(input.currentA, config.currentLimitA) - iq) * config.piQ.kp;
                    integral[0] = fmax(-cap, fmin(cap, -id * config.piD.ki * config.periodS));
                    integral[1] =
                        fmax(-cap, fmin(cap, (fmin(input.currentA, config.currentLimitA) - iq) *
                                                 config.piQ.ki * config.periodS));
                    for (axis = 0; axis < 2; ++axis)
                    {
                        untracked[axis] = integral[axis];
                        voltage[axis] = fmax(-cap, fmin(cap, p[axis] + integral[axis]));
                    }
                    length = hypot(voltage[0], voltage[1]);
                    if (length > cap)
                    {
                        for (axis = 0; axis < 2; ++axis)
                        {
                            voltage[axis] *= cap / length;
                            integral[axis] = fmax(-cap, fmin(cap, voltage[axis] - p[axis]));
                        }
                    }
                    phase[0] =
                        voltage[0] * cos(output.thetaRad) - voltage[1] * sin(output.thetaRad);
                    beta = voltage[0] * sin(output.thetaRad) + voltage[1] * cos(output.thetaRad);
                    phase[1] = -phase[0] / 2.0 + sqrt(3.0) * beta / 2.0;
                    phase[2] = -phase[0] / 2.0 - sqrt(3.0) * beta / 2.0;
                    common = -(fmax(phase[0], fmax(phase[1], phase[2])) +
                               fmin(phase[0], fmin(phase[1], phase[2]))) /
                             2.0;
                    for (axis = 0; axis < 3; ++axis)
                    {
                        duty[axis] = 0.5 + (phase[axis] + common) / input.busVoltageV;
                        CHECK(fabs(output.duty[axis] - duty[axis]) < 2e-6);
                        CHECK(output.duty[axis] >= config.dutyMargin &&
                              output.duty[axis] <= 1.0f - config.dutyMargin);
                    }
                    for (axis = 0; axis < 2; ++axis)
                    {
                        double integralError = fabs(controller.pi[axis].integral - integral[axis]);
                        CHECK(fabs(output.voltageDqV[axis] - voltage[axis]) < 2e-5);
                        /* 圆周边界允许 float 舍入改变比较分支；仍逐项核对两种合法积分。 */
                        if (fabs(length - cap) <= 16.0 * FLT_EPSILON * cap)
                        {
                            const double tracked = fmax(-cap, fmin(cap, voltage[axis] - p[axis]));
                            integralError =
                                fmin(fabs(controller.pi[axis].integral - untracked[axis]),
                                     fabs(controller.pi[axis].integral - tracked));
                        }
                        CHECK(integralError < 2e-5);
                    }
                    CHECK(output.currentLimited == (input.currentA > config.currentLimitA));
                    ++cases;
                }
            }
        }
    }
    printf("IF independent numeric: %u cases\n", cases);
    return true;
}

/** @brief 百万拍相位和双实例交错推进，零频不漂移，正负微小频率不丢失。 */
static bool check_phase(void)
{
    const float frequencies[] = {0.0f, 0.0001f, -0.0001f, 10.0f, -10.0f};
    size_t item;
    for (item = 0; item < sizeof(frequencies) / sizeof(frequencies[0]); ++item)
    {
        IfConfig config = test_config();
        IfController controller = {0}, other = {0};
        IfInput input = test_input(), idle = test_input();
        IfOutput output, otherOutput;
        double expected, largest = 0.0;
        unsigned tick;
        config.periodS = 0.0001f;
        config.alignAngleRad = 5.9f;
        config.alignRampS = 0.0f;
        config.alignHoldS = config.periodS;
        config.frequencyRampS = 0.0f;
        input.currentA = 0.0f;
        input.frequencyHz = frequencies[item];
        idle = input;
        idle.frequencyHz = 0.0f;
        CHECK(if_init(&controller, &config) == IF_OK && if_init(&other, &config) == IF_OK);
        CHECK(enter_run(&controller, &input, &output) && enter_run(&other, &idle, &otherOutput));
        expected = output.thetaRad;
        for (tick = 0; tick < 1000000u; ++tick)
        {
            double error;
            expected =
                fmod(expected + 2.0 * TEST_PI * frequencies[item] * config.periodS + 2.0 * TEST_PI,
                     2.0 * TEST_PI);
            CHECK(if_update(&controller, &input, &output) == IF_OK);
            error = fabs(expected - output.thetaRad);
            error = fmin(error, 2.0 * TEST_PI - error);
            largest = fmax(largest, error);
            CHECK(error <= 0.005);
            if (tick % 1000u == 0u)
            {
                const float held = otherOutput.thetaRad;
                CHECK(if_update(&other, &idle, &otherOutput) == IF_OK);
                CHECK(otherOutput.thetaRad == held);
            }
        }
        printf("IF phase %.7g Hz: max error %.9g rad\n", frequencies[item], largest);
    }
    return true;
}

/** @brief 所有优化级别都执行真实控制入口。 */
int main(void)
{
    return check_start() && check_errors() && check_numeric() && check_phase() ? EXIT_SUCCESS
                                                                               : EXIT_FAILURE;
}
