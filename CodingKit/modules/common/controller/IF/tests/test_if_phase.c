/*
    用独立 long double 参考核对软件电角度积分、环绕、在线输入和累计精度
*/
#include "if_controller.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_TWO_PI (6.283185307179586476925286766559L)
#define CHECK(condition)                                                                                               \
    do {                                                                                                               \
        if (!(condition)) {                                                                                            \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition);                                            \
            return false;                                                                                              \
        }                                                                                                              \
    } while (0)

/* 参考角度及整段运行中的最大圆周误差，单位 rad */
typedef struct {
    long double phaseRad;
    long double maxPhaseErrorRad;
    long double maxOutputErrorRad;
} PhaseReference;

static bool check_tick(double *phaseRad, float frequencyHz, float periodS, PhaseReference *reference);
static bool check_zero_and_initial(void);
static bool check_wrap(void);
static bool check_output_rounding(void);
static bool check_online_inputs(void);
static bool check_reinit(void);
static bool check_instances(void);
static bool check_million_ticks(void);

/* 参考模型使用余数函数，不调用生产代码的环绕逻辑 */
static bool check_tick(double *phaseRad, float frequencyHz, float periodS, PhaseReference *reference)
{
    const long double increment = TEST_TWO_PI * (long double)frequencyHz * (long double)periodS;
    float output;
    long double phaseError, outputError;
    reference->phaseRad = fmodl(reference->phaseRad + increment + TEST_TWO_PI, TEST_TWO_PI);
    output = if_crtl(phaseRad, frequencyHz, periodS);
    CHECK(*phaseRad >= 0.0 && *phaseRad < (double)TEST_TWO_PI);
    CHECK(output >= 0.0f && output < (float)TEST_TWO_PI);
    phaseError = fabsl(remainderl((long double)*phaseRad - reference->phaseRad, TEST_TWO_PI));
    outputError = fabsl(remainderl((long double)output - reference->phaseRad, TEST_TWO_PI));
    reference->maxPhaseErrorRad = fmaxl(reference->maxPhaseErrorRad, phaseError);
    reference->maxOutputErrorRad = fmaxl(reference->maxOutputErrorRad, outputError);
    CHECK(phaseError < 1e-8L);
    CHECK(outputError < 3e-7L);
    return true;
}

/* 零频保持原相位，初始角覆盖零、最小正 float 及上界前一个 float */
static bool check_zero_and_initial(void)
{
    const float initialAngles[] = {0.0f, nextafterf(0.0f, 1.0f), 1.0f, 3.1415926f,
                                   nextafterf((float)TEST_TWO_PI, 0.0f)};
    size_t item;
    for (item = 0; item < sizeof(initialAngles) / sizeof(initialAngles[0]); ++item) {
        double phaseRad;
        unsigned tick;
        if_init(&phaseRad, initialAngles[item]);
        CHECK(phaseRad == (double)initialAngles[item]);
        for (tick = 0; tick < 1000u; ++tick) {
            const float output = if_crtl(&phaseRad, 0.0f, 0.0001f);
            CHECK(phaseRad == (double)initialAngles[item]);
            CHECK(output == initialAngles[item]);
        }
    }
    return true;
}

/* 从上下边界向正反方向推进，也覆盖接近半周期的单拍增量 */
static bool check_wrap(void)
{
    const float starts[] = {0.0f, 0.01f, nextafterf((float)TEST_TWO_PI, 0.0f), 5.9f};
    const float frequencies[] = {-10.0f, -400.0f, 10.0f, 400.0f};
    size_t item;
    for (item = 0; item < 4u; ++item) {
        double phaseRad;
        PhaseReference reference = {(long double)starts[item], 0.0L, 0.0L};
        unsigned tick;
        if_init(&phaseRad, starts[item]);
        for (tick = 0; tick < 100u; ++tick) {
            CHECK(check_tick(&phaseRad, frequencies[item], 0.001f, &reference));
        }
    }
    return true;
}

/* 返回值可向上舍入成整周期；折回零只影响输出，不得覆盖 double 累计值 */
static bool check_output_rounding(void)
{
    double phaseRad;
    double held;
    unsigned tick;
    if_init(&phaseRad, 0.0f);
    CHECK(if_crtl(&phaseRad, -0.0001f, 0.0001f) == 0.0f);
    CHECK(phaseRad > (double)TEST_TWO_PI - 1e-6 && phaseRad < (double)TEST_TWO_PI);
    held = phaseRad;
    for (tick = 0; tick < 10u; ++tick) {
        CHECK(if_crtl(&phaseRad, 0.0f, 0.0001f) == 0.0f);
        CHECK(phaseRad == held);
    }
    (void)if_crtl(&phaseRad, 0.0001f, 0.0001f);
    CHECK(phaseRad < 1e-12);
    return true;
}

/* 频率及采样周期每拍可改，正反转及零频由当拍输入直接决定 */
static bool check_online_inputs(void)
{
    const float frequencies[] = {0.0f, 10.0f, -8.0f, 123.0f, -321.0f, 0.0001f, -0.0001f, 0.0f};
    const float periods[] = {0.0001f, 0.0002f, 0.0003f, 0.002f, 0.001f, 0.01f, 0.005f, 0.02f};
    const float initialAngle = 2.3f;
    double phaseRad;
    PhaseReference reference = {(long double)initialAngle, 0.0L, 0.0L};
    unsigned pass;
    size_t item;
    if_init(&phaseRad, initialAngle);
    for (pass = 0; pass < 128u; ++pass) {
        for (item = 0; item < sizeof(frequencies) / sizeof(frequencies[0]); ++item) {
            CHECK(check_tick(&phaseRad, frequencies[item], periods[item], &reference));
        }
    }
    return true;
}

/* 重新初始化立即采用新角度，不保留上一次累计结果 */
static bool check_reinit(void)
{
    double phaseRad;
    const float initialAngle = 5.4f;
    PhaseReference reference = {(long double)initialAngle, 0.0L, 0.0L};
    if_init(&phaseRad, 0.3f);
    (void)if_crtl(&phaseRad, 15.0f, 0.001f);
    if_init(&phaseRad, initialAngle);
    CHECK(phaseRad == (double)initialAngle);
    CHECK(if_crtl(&phaseRad, 0.0f, 0.0001f) == initialAngle);
    CHECK(check_tick(&phaseRad, -4.0f, 0.001f, &reference));
    return true;
}

/* 两个调用方相位交错更新，彼此不共享累计历史 */
static bool check_instances(void)
{
    const float initialA = 0.2f, initialB = 5.9f;
    double phaseA, phaseB;
    PhaseReference referenceA = {(long double)initialA, 0.0L, 0.0L};
    PhaseReference referenceB = {(long double)initialB, 0.0L, 0.0L};
    unsigned tick;
    if_init(&phaseA, initialA);
    if_init(&phaseB, initialB);
    for (tick = 0; tick < 10000u; ++tick) {
        const double heldB = phaseB;
        CHECK(check_tick(&phaseA, 7.0f, 0.0001f, &referenceA));
        CHECK(phaseB == heldB);
        if (tick % 7u == 0u) {
            const double heldA = phaseA;
            CHECK(check_tick(&phaseB, -11.0f, 0.0002f, &referenceB));
            CHECK(phaseA == heldA);
        }
    }
    return true;
}

/* 微小频率和常用频率各累计百万拍，逐拍检查内部及返回角误差 */
static bool check_million_ticks(void)
{
    const float frequencies[] = {0.0001f, -0.0001f, 10.0f, -10.0f};
    const float initialAngle = 5.9f;
    size_t item;
    for (item = 0; item < sizeof(frequencies) / sizeof(frequencies[0]); ++item) {
        double phaseRad;
        PhaseReference reference = {(long double)initialAngle, 0.0L, 0.0L};
        unsigned tick;
        if_init(&phaseRad, initialAngle);
        for (tick = 0; tick < 1000000u; ++tick) {
            CHECK(check_tick(&phaseRad, frequencies[item], 0.0001f, &reference));
        }
        printf("IF phase %.7g Hz: internal %.9g rad, output %.9g rad\n", frequencies[item],
               (double)reference.maxPhaseErrorRad, (double)reference.maxOutputErrorRad);
    }
    return true;
}

/* 仅验证有效输入合同，不引入启动、电流环或错误管理 */
int main(void)
{
    return check_zero_and_initial() && check_wrap() && check_output_rounding() && check_online_inputs() &&
                   check_reinit() && check_instances() && check_million_ticks()
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
}
