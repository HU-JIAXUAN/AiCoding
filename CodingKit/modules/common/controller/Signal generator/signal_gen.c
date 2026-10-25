/*
    signal_gen.c
    检查波形参数，计算当前输出，再推进相位和时间
    作者 HU JIAXUAN
    日期 2026-10-25
*/
#include "signal_gen.h"

#include <float.h>
#include <tgmath.h> /* C99按参数类型自动选择sinf/sin等函数 */
#include <string.h>

#define SG_PI ((SignalGenReal)3.14159265358979323846)
#define SG_TWO_PI (2.0f * SG_PI)

/* 每种波形各自计算并推进自己的进度，统一入口只负责选择 */
static SignalGenReal generate_dc(SignalGen *generator, bool enable);
static SignalGenReal generate_step(SignalGen *generator, bool enable);
static SignalGenReal generate_sine(SignalGen *generator, bool enable);
static SignalGenReal generate_square(SignalGen *generator, bool enable);
static SignalGenReal generate_triangle(SignalGen *generator, bool enable);
static SignalGenReal generate_trapezoid(SignalGen *generator, bool enable);
static SignalGenReal generate_linear_chirp(SignalGen *generator, bool enable);
static SignalGenReal generate_log_chirp(SignalGen *generator, bool enable);
static SignalGenReal generate_prbs(SignalGen *generator, bool enable);
static SignalGenReal generate_noise(SignalGen *generator, bool enable);
static SignalGenReal generate_multisine(SignalGen *generator, bool enable);

/* 各波形共用的计时、幅值处理和基础计算 */
static double prepare_step(SignalGen *generator, bool enable);
static bool save_output(SignalGen *generator, SignalGenReal basicValue, SignalGenReal frequencyHz);
static SignalGenReal fade_scale(const SignalGenConfig *config, double timeS);
static double phase_wrap(double phase);
static bool phase_advance(double increment, double *phase);
static uint32_t noise_next(uint32_t state);
static uint32_t prbs_next(uint32_t state);
static SignalGenReal noise_value(uint32_t state);
static bool frequency_valid(SignalGenReal frequencyHz, double periodS);
static SignalGenStatus config_check(const SignalGenConfig *config);

/* 统一选择入口 */

/* 按设置的波形选择对应函数，直接返回这次的输出值 */
SignalGenReal signal_gen_update(SignalGen *generator, bool enable)
{
    if (generator == NULL)
    {
        return 0.0f;
    }
    switch (generator->config.wave)
    {
        case SIGNAL_GEN_DC:
            return generate_dc(generator, enable);
        case SIGNAL_GEN_STEP:
            return generate_step(generator, enable);
        case SIGNAL_GEN_SINE:
            return generate_sine(generator, enable);
        case SIGNAL_GEN_SQUARE:
            return generate_square(generator, enable);
        case SIGNAL_GEN_TRIANGLE:
            return generate_triangle(generator, enable);
        case SIGNAL_GEN_TRAPEZOID:
            return generate_trapezoid(generator, enable);
        case SIGNAL_GEN_CHIRP_LINEAR:
            return generate_linear_chirp(generator, enable);
        case SIGNAL_GEN_CHIRP_LOG:
            return generate_log_chirp(generator, enable);
        case SIGNAL_GEN_PRBS:
            return generate_prbs(generator, enable);
        case SIGNAL_GEN_NOISE:
            return generate_noise(generator, enable);
        case SIGNAL_GEN_MULTISINE:
            return generate_multisine(generator, enable);
        default:
            generator->active = false;
            generator->status = SIGNAL_GEN_ERR_CONFIG;
            generator->output = generator->initialized ? generator->config.offset : 0.0f;
            return generator->output;
    }
}

/* 11种波形的计算 */

/* 直流：基本值为1，乘幅值再加偏置后就是 offset + amplitude */
static SignalGenReal generate_dc(SignalGen *generator, bool enable)
{
    if (prepare_step(generator, enable) <= 0.0f)
    {
        return generator->output;
    }
    save_output(generator, 1.0f, 0.0f);
    return generator->output;
}

/* 阶跃：到atS秒之前使用before，之后使用after；两者都是幅值比例 */
static SignalGenReal generate_step(SignalGen *generator, bool enable)
{
    SignalGenReal value;
    if (prepare_step(generator, enable) <= 0.0f)
    {
        return generator->output;
    }
    value = generator->elapsedS < generator->config.step.atS ? generator->config.step.before
                                                             : generator->config.step.after;
    save_output(generator, value, 0.0f);
    return generator->output;
}

/* 正弦：相位一周为1，先计算sin(2*pi*相位)，再前进“频率Hz*时间s”周 */
static SignalGenReal generate_sine(SignalGen *generator, bool enable)
{
    double stepS = prepare_step(generator, enable);
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    if (save_output(generator, sin(SG_TWO_PI * (SignalGenReal)generator->phase),
                    generator->config.frequencyHz))
    {
        phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase);
    }
    return generator->output;
}

/* 方波：相位小于duty时输出高电平，其余为低电平；duty=0.3表示30%高电平 */
static SignalGenReal generate_square(SignalGen *generator, bool enable)
{
    double stepS = prepare_step(generator, enable);
    SignalGenReal value;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    value = generator->phase < generator->config.duty ? 1.0f : -1.0f;
    if (save_output(generator, value, generator->config.frequencyHz))
    {
        phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase);
    }
    return generator->output;
}

/* 三角波：前半周从-1匀速升到1，后半周再匀速降到-1 */
static SignalGenReal generate_triangle(SignalGen *generator, bool enable)
{
    double stepS = prepare_step(generator, enable);
    SignalGenReal phase = (SignalGenReal)generator->phase;
    SignalGenReal value;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    value = phase < 0.5f ? -1.0f + 4.0f * phase : 3.0f - 4.0f * phase;
    if (save_output(generator, value, generator->config.frequencyHz))
    {
        phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase);
    }
    return generator->output;
}

/* 梯形波：按rise、high、fall所占周期比例，依次上升、保持、下降、保持 */
static SignalGenReal generate_trapezoid(SignalGen *generator, bool enable)
{
    const SignalGenTrapezoid *shape = &generator->config.trapezoid;
    double stepS = prepare_step(generator, enable);
    SignalGenReal phase = (SignalGenReal)generator->phase;
    SignalGenReal value;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    if (phase < shape->rise)
    {
        value = -1.0f + 2.0f * phase / shape->rise;
    }
    else if (phase < shape->rise + shape->high)
    {
        value = 1.0f;
    }
    else if (phase < shape->rise + shape->high + shape->fall)
    {
        value = 1.0f - 2.0f * (phase - shape->rise - shape->high) / shape->fall;
    }
    else
    {
        value = -1.0f;
    }
    if (save_output(generator, value, generator->config.frequencyHz))
    {
        phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase);
    }
    return generator->output;
}

/* 线性扫频：按“已运行时间/总时长”计算当前频率，相位按这一小段的平均频率计算 */
static SignalGenReal generate_linear_chirp(SignalGen *generator, bool enable)
{
    const SignalGenConfig *config = &generator->config;
    double stepS = prepare_step(generator, enable);
    SignalGenReal deltaHz, frequencyHz, endHz;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    deltaHz = config->chirp.endHz - config->chirp.startHz;
    frequencyHz =
        config->chirp.startHz + deltaHz * (SignalGenReal)(generator->elapsedS / config->durationS);
    endHz = config->chirp.startHz +
            deltaHz * (SignalGenReal)fmin(1.0, (generator->elapsedS + stepS) / config->durationS);
    if (save_output(generator, sin(SG_TWO_PI * (SignalGenReal)generator->phase), frequencyHz))
    {
        /* Hz乘秒得到走过的周数；频率线性变化，所以用起止频率的平均值 */
        phase_advance(((double)frequencyHz + endHz) * 0.5f * stepS, &generator->phase);
    }
    return generator->output;
}

/* 对数扫频：频率按指数变化，对这一步的频率积分得到相位增量，不能直接用f(t)*t */
static SignalGenReal generate_log_chirp(SignalGen *generator, bool enable)
{
    const SignalGenConfig *config = &generator->config;
    double stepS = prepare_step(generator, enable);
    SignalGenReal frequencyHz, exponent;
    double cycles;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    frequencyHz =
        config->chirp.startHz *
        exp(generator->logRatio * (SignalGenReal)(generator->elapsedS / config->durationS));
    exponent = generator->logRatio * (SignalGenReal)(stepS / config->durationS);
    /* expm1(x)就是exp(x)-1；x很小时仍能准确算出两者之差 相同起止频率按定频处理 */
    cycles =
        exponent == 0.0f ? frequencyHz * stepS : frequencyHz * stepS * expm1(exponent) / exponent;
    if (save_output(generator, sin(SG_TWO_PI * (SignalGenReal)generator->phase), frequencyHz))
    {
        phase_advance(cycles, &generator->phase);
    }
    return generator->output;
}

/* PRBS：最低位决定高低电平，码元时间走完后才移位换码；frequencyHz表示每秒换码次数 */
static SignalGenReal generate_prbs(SignalGen *generator, bool enable)
{
    double stepS = prepare_step(generator, enable);
    SignalGenReal value;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    value = (generator->prbs & UINT32_C(1)) != 0u ? 1.0f : -1.0f;
    if (save_output(generator, value, generator->config.frequencyHz))
    {
        if (phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase))
        {
            generator->prbs = prbs_next(generator->prbs);
        }
    }
    return generator->output;
}

/* 噪声：未到刷新时间就保持上个数，到时再用本路保存的整数算下一个随机数 */
static SignalGenReal generate_noise(SignalGen *generator, bool enable)
{
    double stepS = prepare_step(generator, enable);
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    if (save_output(generator, generator->noiseValue, generator->config.frequencyHz))
    {
        if (phase_advance((double)generator->config.frequencyHz * stepS, &generator->phase))
        {
            generator->prng = noise_next(generator->prng);
            generator->noiseValue = noise_value(generator->prng);
        }
    }
    return generator->output;
}

/* 多正弦：每路按自己的相位算正弦，按权重分配总幅值，相加后各自推进相位 */
static SignalGenReal generate_multisine(SignalGen *generator, bool enable)
{
    const SignalGenMultisine *multi = &generator->config.multisine;
    double stepS = prepare_step(generator, enable);
    SignalGenReal value = 0.0f;
    size_t index;
    if (stepS <= 0.0f)
    {
        return generator->output;
    }
    for (index = 0u; index < multi->count; index++)
    {
        value += (multi->tones[index].weight / generator->weightSum) *
                 sin(SG_TWO_PI * (SignalGenReal)generator->tonePhase[index]);
    }
    value = fmax(-1.0f, fmin(1.0f, value));
    if (save_output(generator, value, 0.0f))
    {
        for (index = 0u; index < multi->count; index++)
        {
            phase_advance((double)multi->tones[index].frequencyHz * stepS,
                          &generator->tonePhase[index]);
        }
    }
    return generator->output;
}

/* 初始化与重播 */

/* 默认不输出激励；各专用参数也给出常用值，用户只改需要的项 */
SignalGenConfig signal_gen_defaults(double periodS)
{
    SignalGenConfig config;
    memset(&config, 0, sizeof(config));
    config.wave = SIGNAL_GEN_DC;
    config.periodS = periodS;
    config.duty = 0.5f;
    config.seed = 1u;
    config.step.after = 1.0f;
    config.trapezoid = (SignalGenTrapezoid){0.25f, 0.25f, 0.25f};
    config.chirp = (SignalGenChirp){1.0f, 10.0f};
    return config;
}

/* 参数检查通过后再保存，因此错误参数不会覆盖原来正在使用的设置 */
SignalGenStatus signal_gen_init(SignalGen *generator, const SignalGenConfig *config)
{
    SignalGenConfig settings;
    SignalGenStatus status;
    size_t index;
    if (generator == NULL)
    {
        return SIGNAL_GEN_ERR_INPUT;
    }
    status = config_check(config);
    if (status != SIGNAL_GEN_OK)
    {
        return status;
    }
    /* reset会把当前config传回来，先保存参数，再清除运行进度 */
    settings = *config;
    memset(generator, 0, sizeof(*generator));
    generator->config = settings;
    generator->phase = phase_wrap(settings.phaseCycles);
    generator->prbs = settings.seed;
    generator->prng = noise_next(settings.seed);
    generator->noiseValue = noise_value(generator->prng);
    if (settings.wave == SIGNAL_GEN_CHIRP_LOG)
    {
        generator->logRatio = log(settings.chirp.endHz / settings.chirp.startHz);
    }
    if (settings.wave == SIGNAL_GEN_MULTISINE)
    {
        for (index = 0u; index < settings.multisine.count; index++)
        {
            generator->weightSum += fabs(settings.multisine.tones[index].weight);
            generator->tonePhase[index] = phase_wrap(
                generator->phase + phase_wrap(settings.multisine.tones[index].phaseCycles));
        }
    }
    generator->initialized = true;
    return SIGNAL_GEN_OK;
}

/* 更换参数会重新开始；传入错误参数时，原来的波形继续保留 */
SignalGenStatus signal_gen_cfg(SignalGen *generator, const SignalGenConfig *config)
{
    if (generator == NULL)
    {
        return SIGNAL_GEN_ERR_INPUT;
    }
    if (!generator->initialized)
    {
        return SIGNAL_GEN_ERR_STATE;
    }
    return signal_gen_init(generator, config);
}

/* 用保存的参数重新开始，相位、时间和随机序列都回到起点 */
SignalGenStatus signal_gen_reset(SignalGen *generator)
{
    if (generator == NULL)
    {
        return SIGNAL_GEN_ERR_INPUT;
    }
    if (!generator->initialized)
    {
        return SIGNAL_GEN_ERR_STATE;
    }
    return signal_gen_init(generator, &generator->config);
}

/* 共用的启停、计时和幅值处理 */

/*
    处理暂停、结束和当前时间，返回本次输出后要前进多少秒；不运行时返回0
    每种波形都需要相同的启停和计时，所以放在这里共用，不在11个函数里重复写
*/
static double prepare_step(SignalGen *generator, bool enable)
{
    const SignalGenConfig *config;
    double timeS;
    generator->active = false;
    generator->output = 0.0f;
    if (!generator->initialized)
    {
        generator->status = SIGNAL_GEN_ERR_STATE;
        return 0.0f;
    }
    config = &generator->config;
    generator->output = config->offset;
    if (generator->sampleIndex == UINT64_MAX)
    {
        generator->status = SIGNAL_GEN_ERR_STATE;
        return 0.0f;
    }
    timeS = (double)generator->sampleIndex * config->periodS;
    if (!isfinite(timeS))
    {
        generator->status = SIGNAL_GEN_ERR_NUMBER;
        return 0.0f;
    }
    generator->elapsedS = timeS;
    generator->phaseCycles = config->wave == SIGNAL_GEN_MULTISINE ? 0.0f : generator->phase;
    generator->currentFrequencyHz = 0.0f;
    /* 避免0.07秒/10毫秒因浮点误差多输出一点；正时长至少输出第0点 */
    generator->finished =
        config->durationS > 0.0f && generator->sampleIndex > 0u &&
        config->durationS - timeS <= 8.0f * DBL_EPSILON * fmax(config->durationS, timeS);
    generator->status = generator->finished ? SIGNAL_GEN_DONE : SIGNAL_GEN_OK;
    if (generator->finished || !enable)
    {
        return 0.0f;
    }
    /* 最后一步只走到结束时间；普通周期波和随机序列也遵守这个时间 */
    return config->durationS > 0.0f ? fmin(config->periodS, config->durationS - timeS)
                                    : config->periodS;
}

/* 基本波形乘幅值、加偏置，保存当前结果并把输出点数加1；计算有误时保留偏置且不推进 */
static bool save_output(SignalGen *generator, SignalGenReal basicValue, SignalGenReal frequencyHz)
{
    const SignalGenConfig *config = &generator->config;
    SignalGenReal value =
        config->offset + config->amplitude * fade_scale(config, generator->elapsedS) * basicValue;
    if (!isfinite(value) || !isfinite(frequencyHz))
    {
        generator->status = SIGNAL_GEN_ERR_NUMBER;
        return false;
    }
    generator->output = value;
    generator->currentFrequencyHz = frequencyHz;
    generator->active = true;
    generator->sampleIndex++;
    return true;
}

/* 计算幅值系数0~1，使开始和结束时的激励逐渐升高或降低；偏置不变 */
static SignalGenReal fade_scale(const SignalGenConfig *config, double timeS)
{
    if (config->fadeInS > 0.0f && timeS < config->fadeInS)
    {
        return 0.5f - 0.5f * cos(SG_PI * (SignalGenReal)(timeS / config->fadeInS));
    }
    if (config->fadeOutS > 0.0f && timeS > config->durationS - config->fadeOutS)
    {
        return 0.5f -
               0.5f * cos(SG_PI * (SignalGenReal)((config->durationS - timeS) / config->fadeOutS));
    }
    return 1.0f;
}

/* 辅助计算与参数检查 */

/* 把任意初相换算到一周内；例如-0.25周等于0.75周 */
static double phase_wrap(double phase)
{
    double wrapped = fmod(phase, 1.0f);
    return wrapped < 0.0f ? wrapped + 1.0f : wrapped;
}

/* 相位向前走一小步；走满一周就扣去1，返回是否跨过了周界 */
static bool phase_advance(double increment, double *phase)
{
    if (increment == 0.0f)
    {
        return false;
    }
    /* 每次都换码时，相位不变，只向调用方报告“该换下一个码了” */
    if (increment == 1.0f)
    {
        return true;
    }
    *phase += increment;
    /* 留出机器舍入误差，避免应当刚好满一周时被算成略小于1 */
    if (*phase >= 1.0f - 8.0f * DBL_EPSILON)
    {
        *phase = fmax(0.0f, *phase - 1.0f);
        return true;
    }
    return false;
}

/* 用本路保存的整数计算下一个随机数，不影响其他路 */
static uint32_t noise_next(uint32_t state)
{
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}

/* PRBS15采用多项式x^15+x^14+1，移位一次得到下一个码 */
static uint32_t prbs_next(uint32_t state)
{
    uint32_t feedback = ((state >> 14) ^ (state >> 13)) & UINT32_C(1);
    return ((state << 1) & UINT32_C(0x7FFF)) | feedback;
}

/* 将随机整数的高24位换算成[-1,1]之间的小数 */
static SignalGenReal noise_value(uint32_t state)
{
    return (SignalGenReal)(state >> 8) / 8388607.5f - 1.0f;
}

/* 正弦等周期波的基频必须低于采样频率的一半；零频表示保持初相 */
static bool frequency_valid(SignalGenReal frequencyHz, double periodS)
{
    return isfinite(frequencyHz) && frequencyHz >= 0.0f && frequencyHz * periodS < 0.5f;
}

/* 初始化时检查参数，只检查公共参数和所选波形实际使用的参数 */
static SignalGenStatus config_check(const SignalGenConfig *config)
{
    size_t index;
    SignalGenReal weightSum = 0.0f;
    if (config == NULL)
    {
        return SIGNAL_GEN_ERR_INPUT;
    }
    if (!isfinite(config->periodS) || config->periodS <= 0.0f || !isfinite(config->amplitude) ||
        config->amplitude < 0.0f || !isfinite(config->offset) ||
        !isfinite(fabs(config->offset) + config->amplitude) || !isfinite(config->phaseCycles) ||
        !isfinite(config->durationS) || config->durationS < 0.0f || !isfinite(config->fadeInS) ||
        config->fadeInS < 0.0f || !isfinite(config->fadeOutS) || config->fadeOutS < 0.0f)
    {
        return SIGNAL_GEN_ERR_CONFIG;
    }
    if ((config->durationS == 0.0f && config->fadeOutS > 0.0f) ||
        (config->durationS > 0.0f && config->fadeInS + config->fadeOutS > config->durationS))
    {
        return SIGNAL_GEN_ERR_CONFIG;
    }
    switch (config->wave)
    {
        case SIGNAL_GEN_DC:
            break;
        case SIGNAL_GEN_STEP:
            if (!isfinite(config->step.atS) || config->step.atS < 0.0f ||
                !isfinite(config->step.before) || fabs(config->step.before) > 1.0f ||
                !isfinite(config->step.after) || fabs(config->step.after) > 1.0f)
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            break;
        case SIGNAL_GEN_SINE:
        case SIGNAL_GEN_SQUARE:
        case SIGNAL_GEN_TRIANGLE:
        case SIGNAL_GEN_TRAPEZOID:
            if (!frequency_valid(config->frequencyHz, config->periodS))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            if (config->wave == SIGNAL_GEN_SQUARE &&
                (!isfinite(config->duty) || config->duty < 0.0f || config->duty > 1.0f))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            if (config->wave == SIGNAL_GEN_TRAPEZOID &&
                (!isfinite(config->trapezoid.rise) || config->trapezoid.rise <= 0.0f ||
                 !isfinite(config->trapezoid.high) || config->trapezoid.high < 0.0f ||
                 !isfinite(config->trapezoid.fall) || config->trapezoid.fall <= 0.0f ||
                 config->trapezoid.rise + config->trapezoid.high + config->trapezoid.fall > 1.0f))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            break;
        case SIGNAL_GEN_CHIRP_LINEAR:
        case SIGNAL_GEN_CHIRP_LOG:
            if (config->durationS <= 0.0f ||
                !frequency_valid(config->chirp.startHz, config->periodS) ||
                !frequency_valid(config->chirp.endHz, config->periodS))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            if (config->wave == SIGNAL_GEN_CHIRP_LOG &&
                (config->chirp.startHz <= 0.0f || config->chirp.endHz <= 0.0f ||
                 !isfinite(log(config->chirp.endHz / config->chirp.startHz))))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            break;
        case SIGNAL_GEN_PRBS:
        case SIGNAL_GEN_NOISE:
            if (!isfinite(config->frequencyHz) || config->frequencyHz < 0.0f ||
                config->frequencyHz * config->periodS > 1.0f || config->seed == 0u ||
                (config->wave == SIGNAL_GEN_PRBS && config->seed > UINT32_C(0x7FFF)))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            break;
        case SIGNAL_GEN_MULTISINE:
            if (config->multisine.count == 0u || config->multisine.count > SIGNAL_GEN_MAX_TONES)
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            for (index = 0u; index < config->multisine.count; index++)
            {
                const SignalGenTone *tone = &config->multisine.tones[index];
                if (!frequency_valid(tone->frequencyHz, config->periodS) ||
                    !isfinite(tone->weight) || !isfinite(tone->phaseCycles))
                {
                    return SIGNAL_GEN_ERR_CONFIG;
                }
                weightSum += fabs(tone->weight);
            }
            if (weightSum == 0.0f || !isfinite(weightSum))
            {
                return SIGNAL_GEN_ERR_CONFIG;
            }
            break;
        default:
            return SIGNAL_GEN_ERR_CONFIG;
    }
    return SIGNAL_GEN_OK;
}
