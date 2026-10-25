/* 检查生成波形、暂停、重新开始和参数错误处理，不连接硬件 */
#include "signal_gen.h"

#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_REAL_IS_FLOAT (sizeof(SignalGenReal) == sizeof(float))
#define TEST_REAL_MAX (TEST_REAL_IS_FLOAT ? (double)FLT_MAX : DBL_MAX)
#define TEST_PI (3.141592653589793238462643383279502884L)
#define CHECK(expression)                                                                          \
    do                                                                                             \
    {                                                                                              \
        g_checks++;                                                                                \
        if (!(expression))                                                                         \
        {                                                                                          \
            g_failed++;                                                                            \
            (void)fprintf(stderr, "line %d: %s\n", __LINE__, #expression);                         \
        }                                                                                          \
    } while (0)

static size_t g_checks;
static size_t g_failed;
static double g_phaseError;
static double g_chirpError;
static double g_multiError;
static double g_noiseMean;
static double g_noiseVariance;

static double cycle_distance(double actual, long double expected);
static double value_tolerance(double doubleLimit, double scale);
static double phase_tolerance(double doubleLimit);
static void test_periodic(void);
static void test_lifecycle(void);
static void test_chirps(void);
static void test_sequences(void);
static void test_multisine(void);
static void test_invalid(void);

/* 比较两相位的最短距离，0.99周与0.01周相差0.02周 */
static double cycle_distance(double actual, long double expected)
{
    long double reference = expected - floorl(expected);
    double difference = fabs(actual - (double)reference);
    return fmin(difference, fabs(1.0 - difference));
}

/* float输出用8倍相对精度留舍入余量，scale取幅值与偏置可能达到的量级 */
static double value_tolerance(double doubleLimit, double scale)
{
    return TEST_REAL_IS_FLOAT ? 8.0 * FLT_EPSILON * fmax(1.0, scale) : doubleLimit;
}

/* float扫频用1e-6周，即0.00036度；double仍使用原来的检查上限 */
static double phase_tolerance(double doubleLimit)
{
    return TEST_REAL_IS_FLOAT ? 1.0e-6 : doubleLimit;
}

/* 检查幅值、初相、占空比，以及20秒运行后的相位误差 */
static void test_periodic(void)
{
    SignalGen generator;
    SignalGenConfig config = signal_gen_defaults(0.001);
    SignalGenWave modes[] = {SIGNAL_GEN_DC,     SIGNAL_GEN_STEP,     SIGNAL_GEN_SINE,
                             SIGNAL_GEN_SQUARE, SIGNAL_GEN_TRIANGLE, SIGNAL_GEN_TRAPEZOID};
    size_t mode, index;
    double value = 0.0;
    /* 7.3 Hz与1 kHz不整除；每周期直接清零相位会使实际频率偏移 */
    for (mode = 0u; mode < sizeof(modes) / sizeof(modes[0]); mode++)
    {
        size_t highCount = 0u;
        config.wave = modes[mode];
        config.frequencyHz = 7.3;
        config.amplitude = 2.0;
        config.offset = 3.0;
        config.phaseCycles = 0.125;
        config.duty = 0.3;
        config.step.atS = 0.2;
        CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
        for (index = 0u; index < 10000u; index++)
        {
            value = signal_gen_update(&generator, true);
            CHECK(generator.status == SIGNAL_GEN_OK);
            CHECK(value == generator.output);
            CHECK(generator.active && isfinite(value) && value >= 1.0 && value <= 5.0);
            if (modes[mode] == SIGNAL_GEN_SQUARE && value > config.offset)
            {
                highCount++;
            }
            if (modes[mode] != SIGNAL_GEN_DC && modes[mode] != SIGNAL_GEN_STEP)
            {
                double error =
                    cycle_distance(generator.phaseCycles,
                                   (long double)config.phaseCycles +
                                       (long double)index * config.frequencyHz * config.periodS);
                g_phaseError = fmax(g_phaseError, error);
                CHECK(error < 1.0e-8);
            }
        }
        if (modes[mode] == SIGNAL_GEN_SQUARE)
        {
            CHECK(fabs((double)highCount / 10000.0 - 0.3) < 0.001);
        }
    }
    /* 20 kHz调用20 s，生成0.1 Hz正弦。1e-8周相位误差约为3.6e-6度 */
    config.wave = SIGNAL_GEN_SINE;
    config.frequencyHz = 0.1;
    config.periodS = 0.00005;
    config.phaseCycles = 0.125;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 400000u; index++)
    {
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK);
    }
    CHECK(value == generator.output);
    g_phaseError =
        fmax(g_phaseError, cycle_distance(generator.phaseCycles,
                                          (long double)config.phaseCycles +
                                              399999.0L * config.frequencyHz * config.periodS));
    CHECK(g_phaseError < 1.0e-8);
    config = signal_gen_defaults(0.125);
    config.wave = SIGNAL_GEN_TRIANGLE;
    config.frequencyHz = 1.0;
    config.amplitude = 2.0;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 8u; index++)
    {
        static const double expected[8] = {-2.0, -1.0, 0.0, 1.0, 2.0, 1.0, 0.0, -1.0};
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK &&
              fabs(value - expected[index]) < value_tolerance(1.0e-14, config.amplitude));
    }
    config.wave = SIGNAL_GEN_TRAPEZOID;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 8u; index++)
    {
        static const double expected[8] = {-2.0, 0.0, 2.0, 2.0, 2.0, 0.0, -2.0, -2.0};
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK &&
              fabs(value - expected[index]) < value_tolerance(1.0e-14, config.amplitude));
    }
    config.wave = SIGNAL_GEN_SQUARE;
    config.duty = 0.0;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_update(&generator, true) == -2.0);
    config.duty = 1.0;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_update(&generator, true) == 2.0);
    config.wave = SIGNAL_GEN_SINE;
    config.frequencyHz = 0.0;
    config.phaseCycles = -0.75;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(fabs(signal_gen_update(&generator, true) - 2.0) <
          value_tolerance(1.0e-14, config.amplitude));
}

/* 检查首个输出、暂停续播、有限时长、幅值渐入渐出和阶跃时刻 */
static void test_lifecycle(void)
{
    SignalGen generator, reference;
    SignalGenConfig config = signal_gen_defaults(0.001);
    size_t index;
    double value, expected, finishTime, maximumStep = 0.0, previous = 3.0;
    config.wave = SIGNAL_GEN_DC;
    config.amplitude = 2.0;
    config.offset = 3.0;
    config.durationS = 0.1;
    config.fadeInS = 0.02;
    config.fadeOutS = 0.02;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_init(&reference, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 100u; index++)
    {
        value = signal_gen_update(&generator, true);
        expected = signal_gen_update(&reference, true);
        CHECK(generator.status == SIGNAL_GEN_OK && reference.status == SIGNAL_GEN_OK);
        CHECK(value == expected && generator.elapsedS == reference.elapsedS);
        CHECK(generator.active && !generator.finished);
        CHECK(fabs(generator.elapsedS - (double)index * config.periodS) < 1.0e-12);
        maximumStep = fmax(maximumStep, fabs(value - previous));
        previous = value;
        if (index == 0u)
        {
            CHECK(value == 3.0);
        }
        if (index == 10u || index == 90u)
        {
            CHECK(fabs(value - 4.0) < value_tolerance(1.0e-12, config.offset + config.amplitude));
        }
        if (index == 50u)
        {
            CHECK(signal_gen_update(&generator, false) == 3.0);
            CHECK(generator.status == SIGNAL_GEN_OK && !generator.active && !generator.finished);
            CHECK(fabs(generator.elapsedS - 0.051) < 1.0e-12);
        }
    }
    CHECK(maximumStep < 0.158);
    CHECK(signal_gen_update(&generator, true) == 3.0);
    CHECK(generator.status == SIGNAL_GEN_DONE && !generator.active && generator.finished);
    finishTime = generator.elapsedS;
    CHECK(signal_gen_update(&generator, false) == 3.0);
    CHECK(generator.status == SIGNAL_GEN_DONE && generator.elapsedS == finishTime);
    CHECK(signal_gen_reset(&generator) == SIGNAL_GEN_OK);
    CHECK(signal_gen_update(&generator, true) == 3.0 && generator.elapsedS == 0.0);
    config = signal_gen_defaults(0.01);
    config.durationS = 0.07;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 7u; index++)
    {
        (void)signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK);
    }
    (void)signal_gen_update(&generator, true);
    CHECK(generator.status == SIGNAL_GEN_DONE);
    config.durationS = 0.0001;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    (void)signal_gen_update(&generator, true);
    CHECK(generator.status == SIGNAL_GEN_OK);
    (void)signal_gen_update(&generator, true);
    CHECK(generator.status == SIGNAL_GEN_DONE);
    config = signal_gen_defaults(0.01);
    config.wave = SIGNAL_GEN_STEP;
    config.amplitude = 2.0;
    config.step = (SignalGenStep){0.02, 1.0, -0.5};
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_update(&generator, true) == 2.0);
    CHECK(signal_gen_update(&generator, true) == 2.0);
    CHECK(signal_gen_update(&generator, true) == -1.0);
}

/* 用绝对时间解析公式检查升频、降频、等频和末尾不足一拍的扫频 */
static void test_chirps(void)
{
    SignalGen generator;
    SignalGenConfig config = signal_gen_defaults(0.0001);
    size_t mode, direction, index;
    double value;
    config.amplitude = 2.0;
    config.offset = 1.0;
    config.durationS = 0.12345;
    config.phaseCycles = 0.13;
    for (mode = 0u; mode < 2u; mode++)
    {
        config.wave = mode == 0u ? SIGNAL_GEN_CHIRP_LINEAR : SIGNAL_GEN_CHIRP_LOG;
        for (direction = 0u; direction < 3u; direction++)
        {
            config.chirp.startHz = direction == 1u ? 113.0 : 7.0;
            config.chirp.endHz = direction == 0u ? 113.0 : 7.0;
            CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
            for (index = 0u; index < 1235u; index++)
            {
                long double t = (long double)index * config.periodS;
                long double cycles, frequency;
                long double f0 = config.chirp.startHz, f1 = config.chirp.endHz,
                            duration = config.durationS;
                if (mode == 0u)
                {
                    cycles = f0 * t + (f1 - f0) * t * t / (2.0L * duration);
                    frequency = f0 + (f1 - f0) * t / duration;
                }
                else if (f0 == f1)
                {
                    cycles = f0 * t;
                    frequency = f0;
                }
                else
                {
                    long double logarithm = logl(f1 / f0);
                    cycles = f0 * duration * expm1l(logarithm * t / duration) / logarithm;
                    frequency = f0 * expl(logarithm * t / duration);
                }
                value = signal_gen_update(&generator, true);
                CHECK(generator.status == SIGNAL_GEN_OK);
                CHECK(value == generator.output);
                g_chirpError = fmax(g_chirpError, cycle_distance(generator.phaseCycles,
                                                                 config.phaseCycles + cycles));
                CHECK(fabs(generator.currentFrequencyHz - (double)frequency) <
                      value_tolerance(1.0e-10, fabs((double)frequency)));
                /* 正弦相位误差引起的输出误差不超过2*pi*幅值*相位误差 */
                CHECK(fabs(value -
                           (config.offset +
                            config.amplitude *
                                (double)sinl(2.0L * TEST_PI * (config.phaseCycles + cycles)))) <
                      (TEST_REAL_IS_FLOAT
                           ? 2.0 * (double)TEST_PI * config.amplitude * phase_tolerance(1.0e-10) +
                                 value_tolerance(1.0e-9, fabs(config.offset) + config.amplitude)
                           : 1.0e-9));
            }
            CHECK(signal_gen_update(&generator, true) == config.offset);
            CHECK(generator.status == SIGNAL_GEN_DONE);
            {
                long double integral =
                    mode == 0u
                        ? (config.chirp.startHz + config.chirp.endHz) * config.durationS / 2.0L
                        : (config.chirp.startHz == config.chirp.endHz
                               ? config.chirp.startHz * config.durationS
                               : (config.chirp.endHz - config.chirp.startHz) * config.durationS /
                                     logl((long double)config.chirp.endHz / config.chirp.startHz));
                CHECK(cycle_distance(generator.phaseCycles, config.phaseCycles + integral) <
                      phase_tolerance(1.0e-10));
            }
        }
    }
    CHECK(g_chirpError < phase_tolerance(1.0e-10));
}

/* 从公开输出检查PRBS周期、码元保持和随机噪声重放，不读取内部移位寄存器 */
static void test_sequences(void)
{
    SignalGen generator, duplicate, independent;
    SignalGenConfig config = signal_gen_defaults(0.001);
    bool seen[32768] = {false};
    size_t index, ones = 0u;
    uint32_t window = 0u, firstWindow = 0u;
    double symbols[334], value, other, sum = 0.0, sumSquares = 0.0, first;
    config.wave = SIGNAL_GEN_PRBS;
    config.amplitude = 1.0;
    config.frequencyHz = 1000.0;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    /* 每15个连续输出位组成窗口；一周期应遍历全部32767个非零窗口 */
    for (index = 0u; index < 32781u; index++)
    {
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK);
        CHECK(value == 1.0 || value == -1.0);
        if (index < 32767u && value > 0.0)
        {
            ones++;
        }
        window = ((window << 1) & UINT32_C(0x7FFF)) | (value > 0.0 ? UINT32_C(1) : UINT32_C(0));
        if (index >= 14u)
        {
            CHECK(window > 0u && !seen[window]);
            seen[window] = true;
            if (index == 14u)
            {
                firstWindow = window;
            }
        }
    }
    value = signal_gen_update(&generator, true);
    window = ((window << 1) & UINT32_C(0x7FFF)) | (value > 0.0 ? UINT32_C(1) : UINT32_C(0));
    CHECK(window == firstWindow && ones == 16384u);
    /* 333码元/s、1 kHz调用：第k拍应输出第floor(k*333/1000)个码元 */
    config.seed = 1234u;
    CHECK(signal_gen_init(&duplicate, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 334u; index++)
    {
        symbols[index] = signal_gen_update(&duplicate, true);
        CHECK(duplicate.status == SIGNAL_GEN_OK);
    }
    config.frequencyHz = 333.0;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index <= 1000u; index++)
    {
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK);
        CHECK(value == symbols[index * 333u / 1000u]);
    }
    config.frequencyHz = 1000.0;
    config.phaseCycles = 0.5;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    config.phaseCycles = 0.0;
    CHECK(signal_gen_cfg(&duplicate, &config) == SIGNAL_GEN_OK);
    for (index = 0u; index < 100u; index++)
    {
        value = signal_gen_update(&generator, true);
        other = signal_gen_update(&duplicate, true);
        CHECK(generator.status == SIGNAL_GEN_OK && duplicate.status == SIGNAL_GEN_OK &&
              value == other);
    }
    config.wave = SIGNAL_GEN_NOISE;
    config.seed = 1u;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_init(&duplicate, &config) == SIGNAL_GEN_OK);
    config.seed = 7u;
    CHECK(signal_gen_init(&independent, &config) == SIGNAL_GEN_OK);
    value = signal_gen_update(&generator, true);
    CHECK(fabs(value - ((double)(UINT32_C(270369) >> 8) / 8388607.5 - 1.0)) <
          value_tolerance(1.0e-15, 1.0));
    CHECK(signal_gen_reset(&generator) == SIGNAL_GEN_OK);
    for (index = 0u; index < 100000u; index++)
    {
        value = signal_gen_update(&generator, true);
        other = signal_gen_update(&independent, true);
        CHECK(generator.status == SIGNAL_GEN_OK && independent.status == SIGNAL_GEN_OK);
        if (index == 0u)
        {
            CHECK(other != value);
        }
        other = signal_gen_update(&duplicate, true);
        CHECK(duplicate.status == SIGNAL_GEN_OK && value == other && fabs(value) <= 1.0);
        sum += value;
        sumSquares += value * value;
    }
    g_noiseMean = sum / 100000.0;
    g_noiseVariance = sumSquares / 100000.0 - g_noiseMean * g_noiseMean;
    CHECK(fabs(g_noiseMean) < 0.015 && fabs(g_noiseVariance - 1.0 / 3.0) < 0.015);
    config.frequencyHz = 250.0;
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    first = signal_gen_update(&generator, true);
    for (index = 0u; index < 3u; index++)
    {
        CHECK(signal_gen_update(&generator, true) == first);
    }
    CHECK(signal_gen_update(&generator, true) != first);
    CHECK(signal_gen_reset(&generator) == SIGNAL_GEN_OK);
    CHECK(signal_gen_update(&generator, true) == first);
}

/* 检查多正弦输出、均方值、总幅值，以及配置数组是否被正确保存 */
static void test_multisine(void)
{
    SignalGen generator;
    SignalGenConfig config = signal_gen_defaults(0.001), original;
    size_t index, tone;
    double value, squared = 0.0;
    config.wave = SIGNAL_GEN_MULTISINE;
    config.amplitude = 2.0;
    config.offset = 3.0;
    config.phaseCycles = 0.1;
    config.multisine.count = 3u;
    config.multisine.tones[0] = (SignalGenTone){7.0, 1.0, 0.125};
    config.multisine.tones[1] = (SignalGenTone){11.0, -2.0, 0.25};
    config.multisine.tones[2] = (SignalGenTone){19.0, 0.5, 0.375};
    original = config;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    config.multisine.tones[0].frequencyHz = NAN;
    for (index = 0u; index < 1000u; index++)
    {
        long double expected = 0.0L;
        for (tone = 0u; tone < original.multisine.count; tone++)
        {
            const SignalGenTone *component = &original.multisine.tones[tone];
            expected += component->weight / 3.5L *
                        sinl(2.0L * TEST_PI *
                             ((long double)index * original.periodS * component->frequencyHz +
                              original.phaseCycles + component->phaseCycles));
        }
        value = signal_gen_update(&generator, true);
        CHECK(generator.status == SIGNAL_GEN_OK && value == generator.output);
        g_multiError = fmax(g_multiError, fabs(value - (3.0 + 2.0 * (double)expected)));
        CHECK(value >= 1.0 && value <= 5.0);
        squared += (value - 3.0) * (value - 3.0);
    }
    CHECK(g_multiError < value_tolerance(1.0e-10, fabs(original.offset) + original.amplitude));
    CHECK(fabs(sqrt(squared / 1000.0) - original.amplitude * sqrt(5.25 / 24.5)) <
          value_tolerance(1.0e-12, original.amplitude));
    config = original;
    config.multisine.count = SIGNAL_GEN_MAX_TONES;
    config.phaseCycles = 0.0;
    for (index = 0u; index < SIGNAL_GEN_MAX_TONES; index++)
    {
        config.multisine.tones[index] = (SignalGenTone){(double)(index + 1u), 1.0, 0.25};
    }
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(fabs(signal_gen_update(&generator, true) - 5.0) < value_tolerance(1.0e-14, 5.0));
    /* 无法表示权重总和的配置应拒绝，不要求处理没有实际用途的超大权重 */
    for (index = 0u; index < SIGNAL_GEN_MAX_TONES; index++)
    {
        config.multisine.tones[index].weight = (SignalGenReal)(TEST_REAL_MAX / 2.0);
    }
    CHECK(signal_gen_cfg(&generator, &config) == SIGNAL_GEN_ERR_CONFIG);
}

/* 配置错误后，原波形应继续；未初始化或空指针调用返回0 */
static void test_invalid(void)
{
    SignalGen generator, reference, empty = {0};
    SignalGenConfig config = signal_gen_defaults(0.001), bad;
    size_t index;
    double value, expected;
    config.wave = SIGNAL_GEN_SINE;
    config.amplitude = 0.7;
    config.offset = 0.2;
    config.frequencyHz = 7.3;
    CHECK(signal_gen_init(&generator, &config) == SIGNAL_GEN_OK);
    CHECK(signal_gen_init(&reference, &config) == SIGNAL_GEN_OK);
    value = signal_gen_update(&generator, true);
    expected = signal_gen_update(&reference, true);
    CHECK(value == expected && generator.status == reference.status);
    for (index = 0u; index < 14u; index++)
    {
        bad = config;
        switch (index)
        {
            case 0u:
                bad.periodS = 0.0;
                break;
            case 1u:
                bad.amplitude = NAN;
                break;
            case 2u:
                bad.amplitude = -1.0;
                break;
            case 3u:
                bad.wave = SIGNAL_GEN_SINE;
                bad.frequencyHz = 500.0;
                break;
            case 4u:
                bad.wave = SIGNAL_GEN_PRBS;
                bad.seed = 0u;
                break;
            case 5u:
                bad.wave = SIGNAL_GEN_PRBS;
                bad.seed = 32768u;
                break;
            case 6u:
                bad.wave = SIGNAL_GEN_CHIRP_LOG;
                bad.durationS = 1.0;
                bad.chirp.startHz = 0.0;
                break;
            case 7u:
                bad.wave = SIGNAL_GEN_CHIRP_LINEAR;
                break;
            case 8u:
                bad.fadeOutS = 1.0;
                break;
            case 9u:
                bad.durationS = 1.0;
                bad.fadeInS = 0.6;
                bad.fadeOutS = 0.6;
                break;
            case 10u:
                bad.wave = SIGNAL_GEN_MULTISINE;
                bad.multisine.count = 17u;
                break;
            case 11u:
                bad.wave = SIGNAL_GEN_MULTISINE;
                bad.multisine.count = 1u;
                break;
            case 12u:
                bad.amplitude = (SignalGenReal)TEST_REAL_MAX;
                bad.offset = (SignalGenReal)TEST_REAL_MAX;
                break;
            default:
                bad.wave = (SignalGenWave)999;
                break;
        }
        CHECK(signal_gen_cfg(&generator, &bad) < 0);
        CHECK(generator.config.wave == config.wave &&
              generator.config.amplitude == config.amplitude);
        value = signal_gen_update(&generator, true);
        expected = signal_gen_update(&reference, true);
        CHECK(generator.status == SIGNAL_GEN_OK && reference.status == SIGNAL_GEN_OK);
        CHECK(value == expected && generator.elapsedS == reference.elapsedS);
    }
    CHECK(signal_gen_update(&empty, true) == 0.0);
    CHECK(empty.status == SIGNAL_GEN_ERR_STATE && !empty.active);
    CHECK(signal_gen_update(NULL, true) == 0.0);
    CHECK(signal_gen_cfg(&empty, &config) == SIGNAL_GEN_ERR_STATE);
    CHECK(signal_gen_reset(&empty) == SIGNAL_GEN_ERR_STATE);
    CHECK(signal_gen_init(&generator, NULL) == SIGNAL_GEN_ERR_INPUT);
    value = signal_gen_update(&generator, true);
    expected = signal_gen_update(&reference, true);
    CHECK(generator.status == SIGNAL_GEN_OK && value == expected);
}

/* 输出数值检查结果，任意检查失败时返回非零 */
int main(void)
{
    test_periodic();
    test_lifecycle();
    test_chirps();
    test_sequences();
    test_multisine();
    test_invalid();
    if (printf("{\"evidence\":\"signal-generator-host-c99\",\"passed\":%s,\"checks\":%zu,"
               "\"failed\":%zu,"
               "\"real_bytes\":%zu,\"phase_error_cycles\":%.12g,\"chirp_phase_error_cycles\":%.12g,"
               "\"multisine_error\":%.12g,"
               "\"noise_mean\":%.12g,\"noise_variance\":%.12g}\n",
               g_failed == 0u ? "true" : "false", g_checks, g_failed, sizeof(SignalGenReal),
               g_phaseError, g_chirpError, g_multiError, g_noiseMean, g_noiseVariance) < 0)
    {
        return EXIT_FAILURE;
    }
    return g_failed == 0u ? EXIT_SUCCESS : EXIT_FAILURE;
}
