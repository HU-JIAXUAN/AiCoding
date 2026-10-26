#include "motor.h"

#include <float.h>
#include <limits.h>
#include <math.h>

static bool valid_motor(const McMotor *motor);
static bool finite_dq(FocDq value);
static bool finite_phase(FocPhase value);
static bool finite_rl(const McRl *estimator);
static float wrap_angle(float angleRad);
static float limit_value(float value, float limit);

static bool valid_motor(const McMotor *motor)
{
    return motor != NULL && isfinite(motor->resistanceOhm) && motor->resistanceOhm > 0.0f &&
           isfinite(motor->ldH) && motor->ldH > 0.0f && isfinite(motor->lqH) && motor->lqH > 0.0f &&
           isfinite(motor->fluxWb) && motor->fluxWb >= 0.0f && motor->polePairs > 0u &&
           motor->version > 0u;
}

static bool finite_dq(FocDq value)
{
    return isfinite(value.d) && isfinite(value.q);
}

static bool finite_phase(FocPhase value)
{
    return isfinite(value.a) && isfinite(value.b) && isfinite(value.c);
}

static bool finite_rl(const McRl *estimator)
{
    return isfinite(estimator->ii) && isfinite(estimator->iv) && isfinite(estimator->vv) &&
           isfinite(estimator->iy) && isfinite(estimator->vy) && isfinite(estimator->yy);
}

static float wrap_angle(float angleRad)
{
    /* 避免按整圈数循环；有限角度也只有一次模运算 */
    return remainderf(angleRad, FOC_TWO_PI);
}

static float limit_value(float value, float limit)
{
    return fminf(limit, fmaxf(-limit, value));
}

McStatus mc_dq_ff(const McMotor *motor, FocDq currentA, float speedRadS, FocDq *voltageV)
{
    FocDq next;
    if (motor == NULL || voltageV == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!valid_motor(motor))
    {
        return MC_ERR_RANGE;
    }
    if (!finite_dq(currentA) || !isfinite(speedRadS))
    {
        return MC_ERR_NUMBER;
    }
    next.d = -speedRadS * motor->lqH * currentA.q;
    next.q = speedRadS * (motor->ldH * currentA.d + motor->fluxWb);
    if (!finite_dq(next))
    {
        return MC_ERR_NUMBER;
    }
    *voltageV = next;
    return MC_OK;
}

McStatus mc_pi_design(float resistanceOhm, float inductanceH, float periodS, float bandwidthHz,
                      float extraDelayS, McPiDesign *design)
{
    McPiDesign next;
    double a, b, gain, crossover, kpB, kiB, equationB, discriminant, sineSquared, phase,
        phaseMargin;
    double proportionalGain, integralContinuous;
    float integralGain;
    if (design == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(resistanceOhm) || !isfinite(inductanceH) || !isfinite(periodS) ||
        !isfinite(bandwidthHz) || !isfinite(extraDelayS))
    {
        return MC_ERR_NUMBER;
    }
    if (resistanceOhm <= 0.0f || inductanceH <= 0.0f || periodS <= 0.0f || bandwidthHz <= 0.0f ||
        extraDelayS < 0.0f)
    {
        return MC_ERR_RANGE;
    }
    if ((double)bandwidthHz * periodS >= 0.1)
    {
        return MC_ERR_CONSTRAINT;
    }
    /* 精确ZOH对象G=b*z^-1/(1-a*z^-1)，匹配先积分PI的零点a */
    a = exp(-(double)resistanceOhm * periodS / inductanceH);
    b = -expm1(-(double)resistanceOhm * periodS / inductanceH) / resistanceOhm;
    gain = -expm1(-2.0 * 3.14159265358979323846 * bandwidthHz * periodS);
    if (a <= 0.0 || a >= 1.0 || b <= 0.0 || !isfinite(b))
    {
        return MC_ERR_CONSTRAINT;
    }
    proportionalGain = a * gain / b;
    integralContinuous = (1.0 - a) * gain / (b * periodS);
    if (!isfinite(proportionalGain) || !isfinite(integralContinuous) ||
        proportionalGain > FLT_MAX || integralContinuous > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    next.kp = (float)proportionalGain;
    next.ki = (float)integralContinuous;
    next.closedPole = (float)(1.0 - gain);
    if (!isfinite(next.kp) || !isfinite(next.ki))
    {
        return MC_ERR_NUMBER;
    }
    /* 正式PI先在float中计算Ki*Ts；检验真实系数，拒绝下溢或极点元数据退化 */
    integralGain = next.ki * periodS;
    kpB = b * next.kp;
    kiB = b * integralGain;
    if (!isfinite(integralGain) || integralGain <= 0.0f || next.closedPole <= 0.0f ||
        next.closedPole >= 1.0f ||
        !(1.0 - a + kpB > 0.0 && kiB > 0.0 && 2.0 + 2.0 * a - 2.0 * kpB - kiB > 0.0))
    {
        return MC_ERR_CONSTRAINT;
    }
    /* 量化后一般不再精确抵消：解析求真实|C(z)G(z)|=1频点，x=sin²(Omega/2) */
    equationB = (1.0 - a) * (1.0 - a) - kpB * (kpB + kiB);
    discriminant = sqrt(equationB * equationB + 4.0 * a * kiB * kiB);
    sineSquared = equationB >= 0.0 ? kiB * kiB / (2.0 * (equationB + discriminant))
                                   : (-equationB + discriminant) / (8.0 * a);
    if (!(sineSquared > 0.0 && sineSquared < 1.0))
    {
        return MC_ERR_CONSTRAINT;
    }
    phase = 2.0 * asin(sqrt(sineSquared));
    crossover = phase / periodS;
    next.crossoverRadS = (float)crossover;
    phaseMargin = 3.14159265358979323846 +
                  atan2(-0.5 * kiB * sqrt((1.0 - sineSquared) / sineSquared), kpB + 0.5 * kiB) -
                  phase - atan2(a * sin(phase), 1.0 - a * cos(phase)) - crossover * extraDelayS;
    next.phaseMarginRad = (float)phaseMargin;
    if (!isfinite(next.crossoverRadS) || !isfinite(next.phaseMarginRad))
    {
        return MC_ERR_NUMBER;
    }
    if (phaseMargin < 0.78539816339744830962)
    {
        return MC_ERR_CONSTRAINT;
    }
    *design = next;
    return MC_OK;
}

McStatus mc_pi_cfg(PidPi *pi, float kp, float ki, float error, float limit)
{
    PidPi next;
    if (pi == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(pi->kp) || !isfinite(pi->ki) || !isfinite(pi->integral) || !isfinite(kp) ||
        !isfinite(ki) || !isfinite(error) || !isfinite(limit))
    {
        return MC_ERR_NUMBER;
    }
    if (pi->kp < 0.0f || pi->ki < 0.0f || kp < 0.0f || ki < 0.0f || limit <= 0.0f)
    {
        return MC_ERR_RANGE;
    }
    next = *pi;
    next.kp = kp;
    next.ki = ki;
    next.integral = pi->integral + (pi->kp - kp) * error;
    if (!isfinite(next.integral))
    {
        return MC_ERR_NUMBER;
    }
    /* ki=0在正式PI中会清积分；无法无扰则明确拒绝，由应用组织停机切换 */
    if (fabsf(next.integral) > limit || (ki == 0.0f && next.integral != 0.0f))
    {
        return MC_ERR_CONSTRAINT;
    }
    *pi = next;
    return MC_OK;
}

McStatus mc_align_angle(const McAngle *input, float *angleRad)
{
    double age, prediction, angle;
    if (input == NULL || angleRad == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!input->valid)
    {
        return MC_ERR_SAMPLE;
    }
    if (input->alreadyPredicted)
    {
        return MC_ERR_DUPLICATE;
    }
    if (!isfinite(input->angleRad) || !isfinite(input->speedRadS) || !isfinite(input->latchTimeS) ||
        !isfinite(input->targetTimeS) || !isfinite(input->maxAgeS) ||
        !isfinite(input->maxPredictionRad))
    {
        return MC_ERR_NUMBER;
    }
    if (input->maxAgeS < 0.0f || input->maxPredictionRad < 0.0f || input->maxPredictionRad > FOC_PI)
    {
        return MC_ERR_RANGE;
    }
    age = input->targetTimeS - input->latchTimeS;
    if (age < 0.0 || age > input->maxAgeS)
    {
        return MC_ERR_STALE;
    }
    prediction = age * input->speedRadS;
    if (fabs(prediction) > input->maxPredictionRad)
    {
        return MC_ERR_CONSTRAINT;
    }
    angle = remainder((double)input->angleRad + prediction, 2.0 * 3.14159265358979323846);
    *angleRad = (float)angle;
    return MC_OK;
}

McStatus mc_rl_init(McRl *estimator, const McRlConfig *config)
{
    McRlConfig next;
    if (estimator == NULL || config == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(config->periodS) || !isfinite(config->minRankRatio) ||
        !isfinite(config->maxSpeedRadS))
    {
        return MC_ERR_NUMBER;
    }
    if (config->periodS <= 0.0 || config->minRankRatio <= 0.0 || config->minRankRatio >= 1.0 ||
        config->maxSpeedRadS < 0.0 || config->minSamples < 3u || config->version == 0u)
    {
        return MC_ERR_RANGE;
    }
    next = *config;
    *estimator = (McRl){0};
    estimator->config = next;
    return MC_OK;
}

McStatus mc_rl_add(McRl *estimator, const McRlSample *sample)
{
    McRl next;
    double i, v, y;
    if (estimator == NULL || sample == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!sample->valid)
    {
        return MC_ERR_SAMPLE;
    }
    if (sample->version != estimator->config.version || sample->version == 0u)
    {
        return MC_ERR_REVISION;
    }
    if (!isfinite(sample->currentStartA) || !isfinite(sample->currentEndA) ||
        !isfinite(sample->appliedVoltageV) || !isfinite(sample->speedRadS) ||
        !isfinite(sample->periodS))
    {
        return MC_ERR_NUMBER;
    }
    if (estimator->config.periodS <= 0.0 || estimator->count == UINT32_MAX ||
        fabs(sample->periodS - estimator->config.periodS) > estimator->config.periodS * 1e-6)
    {
        return MC_ERR_RANGE;
    }
    if (fabs(sample->speedRadS) > estimator->config.maxSpeedRadS)
    {
        return MC_ERR_CONSTRAINT;
    }
    next = *estimator;
    i = sample->currentStartA;
    v = sample->appliedVoltageV;
    y = sample->currentEndA;
    next.ii += i * i;
    next.iv += i * v;
    next.vv += v * v;
    next.iy += i * y;
    next.vy += v * y;
    next.yy += y * y;
    if (!finite_rl(&next))
    {
        return MC_ERR_NUMBER;
    }
    next.count++;
    *estimator = next;
    return MC_OK;
}

McStatus mc_rl_fit(const McRl *estimator, McRlResult *result)
{
    McRlResult next;
    double normalized, determinant, residual;
    if (estimator == NULL || result == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!finite_rl(estimator))
    {
        return MC_ERR_NUMBER;
    }
    if (estimator->config.periodS <= 0.0 || estimator->config.minRankRatio <= 0.0 ||
        estimator->config.minRankRatio >= 1.0 || estimator->config.minSamples < 3u ||
        estimator->count < estimator->config.minSamples || estimator->ii <= 0.0 ||
        estimator->vv <= 0.0)
    {
        return MC_ERR_EVIDENCE;
    }
    /* 归一化后检查秩，拒绝稳态DC或几乎共线的电流/电压 */
    normalized = (estimator->iv / sqrt(estimator->ii)) / sqrt(estimator->vv);
    next.rankRatio = 1.0 - normalized * normalized;
    if (next.rankRatio < estimator->config.minRankRatio)
    {
        return MC_ERR_EVIDENCE;
    }
    determinant = estimator->ii * estimator->vv - estimator->iv * estimator->iv;
    if (!isfinite(determinant) || determinant <= 0.0)
    {
        return MC_ERR_NUMBER;
    }
    next.pole = (estimator->iy * estimator->vv - estimator->vy * estimator->iv) / determinant;
    next.voltageGain =
        (estimator->vy * estimator->ii - estimator->iy * estimator->iv) / determinant;
    if (!isfinite(next.pole) || !isfinite(next.voltageGain) || next.pole <= 0.0 ||
        next.pole >= 1.0 || next.voltageGain <= 0.0)
    {
        return MC_ERR_CONSTRAINT;
    }
    next.resistanceOhm = (1.0 - next.pole) / next.voltageGain;
    next.inductanceH = -next.resistanceOhm * estimator->config.periodS / log(next.pole);
    residual = estimator->yy - next.pole * estimator->iy - next.voltageGain * estimator->vy;
    /* 有限精度正规方程可能产生微小负残差，只容许舍入量级 */
    if (residual < -64.0 * DBL_EPSILON * fmax(1.0, estimator->yy))
    {
        return MC_ERR_NUMBER;
    }
    next.residualRmsA = sqrt(fmax(0.0, residual) / estimator->count);
    next.samples = estimator->count;
    if (!isfinite(next.resistanceOhm) || !isfinite(next.inductanceH) ||
        !isfinite(next.residualRmsA))
    {
        return MC_ERR_NUMBER;
    }
    *result = next;
    return MC_OK;
}

McStatus mc_mtpa(const McMotor *motor, const McMtpa *request, FocDq *currentA)
{
    double delta, flux, current, d, q;
    if (motor == NULL || request == NULL || currentA == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!valid_motor(motor) || !isfinite(request->currentA) || request->currentA < 0.0f ||
        (request->direction != 1.0f && request->direction != -1.0f))
    {
        return MC_ERR_RANGE;
    }
    if (request->version != motor->version)
    {
        return MC_ERR_REVISION;
    }
    /* 仅常参数Lq>=Ld、正永磁磁链；反凸极/饱和模型不偷偷套用 */
    if (motor->lqH < motor->ldH || motor->fluxWb <= 0.0f)
    {
        return MC_ERR_CONSTRAINT;
    }
    delta = (double)motor->lqH - motor->ldH;
    flux = motor->fluxWb;
    current = request->currentA;
    d = -2.0 * delta * current * current /
        (flux + sqrt(flux * flux + 8.0 * delta * delta * current * current));
    q = request->direction * sqrt(fmax(0.0, current * current - d * d));
    if (fabs(d) > FLT_MAX || fabs(q) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    *currentA = (FocDq){(float)d, (float)q};
    return MC_OK;
}

McStatus mc_torque(const McMotor *motor, FocDq currentA, float *torqueNm)
{
    double next;
    if (motor == NULL || torqueNm == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!valid_motor(motor))
    {
        return MC_ERR_RANGE;
    }
    if (!finite_dq(currentA))
    {
        return MC_ERR_NUMBER;
    }
    next = 1.5 * motor->polePairs *
           ((double)motor->fluxWb + ((double)motor->ldH - motor->lqH) * currentA.d) * currentA.q;
    if (!isfinite(next) || fabs(next) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    *torqueNm = (float)next;
    return MC_OK;
}

McStatus mc_check_limits(const McMotor *motor, FocDq currentA, float speedRadS, float currentLimitA,
                         float voltageLimitV, McLimits *result)
{
    FocDq voltage;
    McLimits next;
    McStatus status;
    if (result == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(currentLimitA) || !isfinite(voltageLimitV) || currentLimitA <= 0.0f ||
        voltageLimitV <= 0.0f)
    {
        return MC_ERR_RANGE;
    }
    status = mc_dq_ff(motor, currentA, speedRadS, &voltage);
    if (status != MC_OK)
    {
        return status;
    }
    voltage.d += motor->resistanceOhm * currentA.d;
    voltage.q += motor->resistanceOhm * currentA.q;
    next.currentMagnitudeA = hypotf(currentA.d, currentA.q);
    next.voltageMagnitudeV = hypotf(voltage.d, voltage.q);
    if (!isfinite(next.currentMagnitudeA) || !isfinite(next.voltageMagnitudeV))
    {
        return MC_ERR_NUMBER;
    }
    next.currentLimited = next.currentMagnitudeA > currentLimitA;
    next.voltageLimited = next.voltageMagnitudeV > voltageLimitV;
    *result = next;
    return MC_OK;
}

McStatus mc_deadtime(const McDeadtime *config, FocPhase currentA, FocPhase *voltageV)
{
    FocPhase next;
    float gain, mean;
    if (config == NULL || voltageV == NULL)
    {
        return MC_ERR_NULL;
    }
    if (config->alreadyCompensated)
    {
        return MC_ERR_DUPLICATE;
    }
    if (!finite_phase(currentA) || !isfinite(config->busVoltageV) ||
        !isfinite(config->effectiveDelayS) || !isfinite(config->pwmPeriodS) ||
        !isfinite(config->transitionA))
    {
        return MC_ERR_NUMBER;
    }
    if (config->busVoltageV <= 0.0f || config->pwmPeriodS <= 0.0f || config->transitionA <= 0.0f ||
        fabsf(config->effectiveDelayS) > 0.25f * config->pwmPeriodS)
    {
        return MC_ERR_RANGE;
    }
    gain = config->busVoltageV * (config->effectiveDelayS / config->pwmPeriodS);
    next.a = gain * limit_value(currentA.a / config->transitionA, 1.0f);
    next.b = gain * limit_value(currentA.b / config->transitionA, 1.0f);
    next.c = gain * limit_value(currentA.c / config->transitionA, 1.0f);
    mean = next.a / 3.0f + next.b / 3.0f + next.c / 3.0f;
    next.a -= mean;
    next.b -= mean;
    next.c -= mean;
    if (!finite_phase(next))
    {
        return MC_ERR_NUMBER;
    }
    *voltageV = next;
    return MC_OK;
}

McStatus mc_friction(const McFriction *config, float speedRadS, float *torqueNm)
{
    double relative, next;
    if (config == NULL || torqueNm == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(speedRadS) || !isfinite(config->coulombNm) || !isfinite(config->staticNm) ||
        !isfinite(config->viscousNms) || !isfinite(config->stribeckRadS) ||
        !isfinite(config->transitionRadS))
    {
        return MC_ERR_NUMBER;
    }
    if (config->coulombNm < 0.0f || config->staticNm < config->coulombNm ||
        config->viscousNms < 0.0f || config->stribeckRadS <= 0.0f || config->transitionRadS <= 0.0f)
    {
        return MC_ERR_RANGE;
    }
    relative = (double)speedRadS / config->stribeckRadS;
    next =
        (config->coulombNm + (config->staticNm - config->coulombNm) * exp(-relative * relative)) *
            tanh((double)speedRadS / config->transitionRadS) +
        (double)config->viscousNms * speedRadS;
    if (!isfinite(next) || fabs(next) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    *torqueNm = (float)next;
    return MC_OK;
}

McStatus mc_mech_ff(const McMechanical *input, float *torqueNm)
{
    double next;
    if (input == NULL || torqueNm == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(input->inertiaKgm2) || !isfinite(input->viscousNms) ||
        !isfinite(input->speedRadS) || !isfinite(input->accelRadS2) ||
        !isfinite(input->knownLoadNm))
    {
        return MC_ERR_NUMBER;
    }
    if (input->inertiaKgm2 <= 0.0f || input->viscousNms < 0.0f)
    {
        return MC_ERR_RANGE;
    }
    next = (double)input->inertiaKgm2 * input->accelRadS2 +
           (double)input->viscousNms * input->speedRadS + input->knownLoadNm;
    if (!isfinite(next) || fabs(next) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    *torqueNm = (float)next;
    return MC_OK;
}

McStatus mc_dob_init(McDob *observer, const McDobConfig *config)
{
    McDobConfig next;
    if (observer == NULL || config == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(config->periodS) || !isfinite(config->inertiaKgm2) ||
        !isfinite(config->bandwidthRadS) || !isfinite(config->maxDisturbanceNm))
    {
        return MC_ERR_NUMBER;
    }
    if (config->periodS <= 0.0f || config->inertiaKgm2 <= 0.0f || config->bandwidthRadS <= 0.0f ||
        config->maxDisturbanceNm <= 0.0f || config->version == 0u ||
        config->bandwidthRadS * config->periodS > 0.5f)
    {
        return MC_ERR_RANGE;
    }
    next = *config;
    *observer = (McDob){0};
    observer->config = next;
    observer->alpha = (float)-expm1(-(double)next.bandwidthRadS * next.periodS);
    return MC_OK;
}

McStatus mc_dob_update(McDob *observer, float appliedTorqueNm, float speedRadS, bool valid,
                       uint32_t version, float *disturbanceNm)
{
    McDob next;
    double raw, estimate;
    if (observer == NULL || disturbanceNm == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!valid)
    {
        observer->primed = false;
        return MC_ERR_SAMPLE;
    }
    if (version == 0u || version != observer->config.version)
    {
        return MC_ERR_REVISION;
    }
    if (!isfinite(appliedTorqueNm) || !isfinite(speedRadS) || !isfinite(observer->estimateNm) ||
        !isfinite(observer->previousSpeedRadS) || !isfinite(observer->alpha))
    {
        return MC_ERR_NUMBER;
    }
    if (observer->config.periodS <= 0.0f || observer->config.inertiaKgm2 <= 0.0f ||
        observer->config.bandwidthRadS <= 0.0f || observer->config.maxDisturbanceNm <= 0.0f ||
        observer->alpha <= 0.0f || observer->alpha > 1.0f)
    {
        return MC_ERR_RANGE;
    }
    next = *observer;
    if (next.primed)
    {
        raw = (double)appliedTorqueNm - observer->config.inertiaKgm2 *
                                            ((double)speedRadS - observer->previousSpeedRadS) /
                                            observer->config.periodS;
        estimate = observer->estimateNm + observer->alpha * (raw - observer->estimateNm);
        if (!isfinite(estimate))
        {
            return MC_ERR_NUMBER;
        }
        next.estimateNm = (float)fmin(observer->config.maxDisturbanceNm,
                                      fmax(-observer->config.maxDisturbanceNm, estimate));
    }
    next.previousSpeedRadS = speedRadS;
    next.primed = true;
    *observer = next;
    *disturbanceNm = next.estimateNm;
    return MC_OK;
}

McStatus mc_notch(float frequencyHz, float zeroDamping, float poleDamping, float periodS,
                  McBiquad *coefficients)
{
    double k, den;
    McBiquad next;
    if (coefficients == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(frequencyHz) || !isfinite(zeroDamping) || !isfinite(poleDamping) ||
        !isfinite(periodS))
    {
        return MC_ERR_NUMBER;
    }
    if (frequencyHz <= 0.0f || periodS <= 0.0f || frequencyHz * periodS >= 0.45f ||
        zeroDamping < 0.0f || poleDamping <= 0.0f || zeroDamping > poleDamping)
    {
        return MC_ERR_RANGE;
    }
    k = tan(3.14159265358979323846 * frequencyHz * periodS);
    den = 1.0 + 2.0 * poleDamping * k + k * k;
    next.b0 = (float)((1.0 + 2.0 * zeroDamping * k + k * k) / den);
    next.b1 = (float)(2.0 * (k * k - 1.0) / den);
    next.b2 = (float)((1.0 - 2.0 * zeroDamping * k + k * k) / den);
    next.a1 = next.b1;
    next.a2 = (float)((1.0 - 2.0 * poleDamping * k + k * k) / den);
    /* 系数量化后仍须严格Schur稳定；过低频/过窄陷波可能在float中退化 */
    if (!(1.0f + next.a1 + next.a2 > 0.0f && 1.0f - next.a1 + next.a2 > 0.0f &&
          1.0f - next.a2 > 0.0f))
    {
        return MC_ERR_CONSTRAINT;
    }
    *coefficients = next;
    return MC_OK;
}

McStatus mc_filter(McBiquadState *state, const McBiquad *coefficients, float input, float *output)
{
    McBiquadState next;
    double value;
    if (state == NULL || coefficients == NULL || output == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(input) || !isfinite(coefficients->b0) || !isfinite(coefficients->b1) ||
        !isfinite(coefficients->b2) || !isfinite(coefficients->a1) || !isfinite(coefficients->a2) ||
        !isfinite(state->x1) || !isfinite(state->x2) || !isfinite(state->y1) ||
        !isfinite(state->y2))
    {
        return MC_ERR_NUMBER;
    }
    if (!(1.0f + coefficients->a1 + coefficients->a2 > 0.0f &&
          1.0f - coefficients->a1 + coefficients->a2 > 0.0f && 1.0f - coefficients->a2 > 0.0f))
    {
        return MC_ERR_CONSTRAINT;
    }
    value = (double)coefficients->b0 * input + (double)coefficients->b1 * state->x1 +
            (double)coefficients->b2 * state->x2 - (double)coefficients->a1 * state->y1 -
            (double)coefficients->a2 * state->y2;
    if (!isfinite(value) || fabs(value) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    next = *state;
    next.x2 = state->x1;
    next.x1 = input;
    next.y2 = state->y1;
    next.y1 = (float)value;
    *state = next;
    *output = (float)value;
    return MC_OK;
}

McStatus mc_pll_init(McPll *pll, float periodS, float bandwidthRadS, float damping,
                     float maxSpeedRadS, uint32_t version)
{
    McPll next = {0};
    double kp, ki, proportionalStep, integralStep;
    if (pll == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(periodS) || !isfinite(bandwidthRadS) || !isfinite(damping) ||
        !isfinite(maxSpeedRadS))
    {
        return MC_ERR_NUMBER;
    }
    if (periodS <= 0.0f || bandwidthRadS <= 0.0f || damping <= 0.0f || maxSpeedRadS <= 0.0f ||
        version == 0u)
    {
        return MC_ERR_RANGE;
    }
    kp = 2.0 * damping * bandwidthRadS;
    ki = (double)bandwidthRadS * bandwidthRadS;
    if (kp > FLT_MAX || ki > FLT_MAX)
    {
        return MC_ERR_CONSTRAINT;
    }
    next.periodS = periodS;
    next.kpRadS = (float)kp;
    next.kiRadS2 = (float)ki;
    /* 先量化到实际保存的float，再对先积分速度/后积分角度的矩阵检验Jury
     * 三项解析化简避免1-trace+det在低带宽时发生相消 */
    proportionalStep = (double)next.kpRadS * next.periodS;
    integralStep = (double)next.kiRadS2 * next.periodS * next.periodS;
    if (!(proportionalStep > 0.0 && integralStep > 0.0 &&
          4.0 - 2.0 * proportionalStep - integralStep > 0.0))
    {
        return MC_ERR_CONSTRAINT;
    }
    next.maxSpeedRadS = maxSpeedRadS;
    next.version = version;
    *pll = next;
    return MC_OK;
}

McStatus mc_pll_update(McPll *pll, float measuredAngleRad, bool valid, uint32_t version)
{
    McPll next;
    float error;
    double speed, angle;
    if (pll == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!valid)
    {
        return MC_ERR_SAMPLE;
    }
    if (version == 0u || version != pll->version)
    {
        return MC_ERR_REVISION;
    }
    if (!isfinite(measuredAngleRad) || !isfinite(pll->angleRad) || !isfinite(pll->speedRadS) ||
        !isfinite(pll->periodS) || !isfinite(pll->kpRadS) || !isfinite(pll->kiRadS2) ||
        !isfinite(pll->maxSpeedRadS))
    {
        return MC_ERR_NUMBER;
    }
    if (pll->periodS <= 0.0f || pll->kpRadS <= 0.0f || pll->kiRadS2 <= 0.0f ||
        pll->maxSpeedRadS <= 0.0f)
    {
        return MC_ERR_RANGE;
    }
    next = *pll;
    error = wrap_angle(wrap_angle(measuredAngleRad) - wrap_angle(pll->angleRad));
    speed = pll->speedRadS + (double)pll->kiRadS2 * pll->periodS * error;
    speed = fmin(pll->maxSpeedRadS, fmax(-pll->maxSpeedRadS, speed));
    angle = pll->angleRad + pll->periodS * (speed + (double)pll->kpRadS * error);
    if (!isfinite(angle))
    {
        return MC_ERR_NUMBER;
    }
    next.speedRadS = (float)speed;
    next.angleRad = (float)remainder(angle, 2.0 * 3.14159265358979323846);
    *pll = next;
    return MC_OK;
}

McStatus mc_dual_error(float motorAngleRad, float loadAngleRad, float ratio, float maxErrorRad,
                       float *loadErrorRad)
{
    double error;
    if (loadErrorRad == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(motorAngleRad) || !isfinite(loadAngleRad) || !isfinite(ratio) ||
        !isfinite(maxErrorRad))
    {
        return MC_ERR_NUMBER;
    }
    if (ratio == 0.0f || maxErrorRad <= 0.0f)
    {
        return MC_ERR_RANGE;
    }
    /* 仅同一时间、同一零点的展开位置；不要在这里折叠多圈误差 */
    error = (double)motorAngleRad / ratio - loadAngleRad;
    if (fabs(error) > maxErrorRad)
    {
        return MC_ERR_CONSTRAINT;
    }
    *loadErrorRad = (float)error;
    return MC_OK;
}

McStatus mc_schedule(uint32_t cycle, uint32_t divisor, uint32_t phase, bool *due)
{
    if (due == NULL)
    {
        return MC_ERR_NULL;
    }
    if (divisor == 0u || phase >= divisor)
    {
        return MC_ERR_RANGE;
    }
    *due = cycle % divisor == phase;
    return MC_OK;
}

McStatus mc_ripple(float angleRad, const float *coefficients, size_t count, float *output)
{
    double result = 0.0;
    size_t index;
    if (coefficients == NULL || output == NULL)
    {
        return MC_ERR_NULL;
    }
    if (count == 0u || count > 32u || count % 2u != 0u)
    {
        return MC_ERR_RANGE;
    }
    if (!isfinite(angleRad))
    {
        return MC_ERR_NUMBER;
    }
    angleRad = wrap_angle(angleRad);
    for (index = 0u; index < count; index += 2u)
    {
        double phase = (index / 2u + 1u) * (double)angleRad;
        if (!isfinite(coefficients[index]) || !isfinite(coefficients[index + 1u]))
        {
            return MC_ERR_NUMBER;
        }
        result += coefficients[index] * cos(phase) + coefficients[index + 1u] * sin(phase);
    }
    if (!isfinite(result) || fabs(result) > FLT_MAX)
    {
        return MC_ERR_NUMBER;
    }
    *output = (float)result;
    return MC_OK;
}

McStatus mc_traj_plan(const McTrajRequest *request, McTrajectory *trajectory)
{
    McTrajectory next;
    double distance, duration, intervals;
    if (request == NULL || trajectory == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(request->startRad) || !isfinite(request->endRad) || !isfinite(request->periodS) ||
        !isfinite(request->maxSpeedRadS) || !isfinite(request->maxAccelRadS2) ||
        !isfinite(request->maxJerkRadS3))
    {
        return MC_ERR_NUMBER;
    }
    if (request->periodS <= 0.0 || request->maxSpeedRadS <= 0.0 || request->maxAccelRadS2 <= 0.0 ||
        request->maxJerkRadS3 <= 0.0)
    {
        return MC_ERR_RANGE;
    }
    distance = fabs(request->endRad - request->startRad);
    /* s(u)=10u³-15u⁴+6u⁵，速度/加速度/jerk的解析峰值 */
    duration = fmax(1.875 * distance / request->maxSpeedRadS,
                    sqrt((10.0 / sqrt(3.0)) * distance / request->maxAccelRadS2));
    duration = fmax(duration, cbrt(60.0 * distance / request->maxJerkRadS3));
    intervals = ceil(duration / request->periodS);
    if (!isfinite(intervals) || intervals > UINT32_MAX)
    {
        return MC_ERR_NUMBER;
    }
    next.startRad = request->startRad;
    next.endRad = request->endRad;
    next.periodS = request->periodS;
    next.samples = (uint32_t)fmax(1.0, intervals);
    *trajectory = next;
    return MC_OK;
}

McStatus mc_traj_sample(const McTrajectory *trajectory, uint32_t index, McTrajectoryPoint *point)
{
    McTrajectoryPoint next;
    double u, distance, duration;
    if (trajectory == NULL || point == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(trajectory->startRad) || !isfinite(trajectory->endRad) ||
        !isfinite(trajectory->periodS))
    {
        return MC_ERR_NUMBER;
    }
    if (trajectory->periodS <= 0.0 || trajectory->samples == 0u)
    {
        return MC_ERR_RANGE;
    }
    if (index >= trajectory->samples)
    {
        *point = (McTrajectoryPoint){trajectory->endRad, 0.0, 0.0, 0.0, true};
        return MC_OK;
    }
    u = (double)index / trajectory->samples;
    distance = trajectory->endRad - trajectory->startRad;
    duration = trajectory->periodS * trajectory->samples;
    next.positionRad = trajectory->startRad + distance * u * u * u * (10.0 + u * (-15.0 + 6.0 * u));
    next.speedRadS = distance * 30.0 * u * u * (1.0 - u) * (1.0 - u) / duration;
    next.accelRadS2 = distance * 60.0 * u * (1.0 - u) * (1.0 - 2.0 * u) / (duration * duration);
    next.jerkRadS3 =
        distance * 60.0 * (1.0 + u * (-6.0 + 6.0 * u)) / (duration * duration * duration);
    next.complete = false;
    if (!isfinite(next.positionRad) || !isfinite(next.speedRadS) || !isfinite(next.accelRadS2) ||
        !isfinite(next.jerkRadS3))
    {
        return MC_ERR_NUMBER;
    }
    *point = next;
    return MC_OK;
}

McStatus mc_frf(const McFrfInput *input, McFrf *result)
{
    McFrf next;
    double cycles, rounded, ur = 0.0, ui = 0.0, yr = 0.0, yi = 0.0, power;
    size_t index;
    if (input == NULL || result == NULL || input->input == NULL || input->output == NULL)
    {
        return MC_ERR_NULL;
    }
    if (input->count < 8u || input->count > 4096u || !isfinite(input->periodS) ||
        !isfinite(input->frequencyHz) || !isfinite(input->minAmplitude) || input->periodS <= 0.0 ||
        input->frequencyHz <= 0.0 || input->minAmplitude <= 0.0)
    {
        return MC_ERR_RANGE;
    }
    cycles = input->frequencyHz * input->periodS * input->count;
    rounded = round(cycles);
    if (!isfinite(cycles) || rounded < 1.0 || rounded >= (double)input->count / 2.0 ||
        fabs(cycles - rounded) > 1e-8 * rounded)
    {
        return MC_ERR_CONSTRAINT;
    }
    for (index = 0u; index < input->count; index++)
    {
        double phase = 2.0 * 3.14159265358979323846 * rounded * index / input->count;
        double sine = sin(phase);
        double cosine = cos(phase);
        if (!isfinite(input->input[index]) || !isfinite(input->output[index]))
        {
            return MC_ERR_NUMBER;
        }
        ur += input->input[index] * cosine;
        ui -= input->input[index] * sine;
        yr += input->output[index] * cosine;
        yi -= input->output[index] * sine;
    }
    next.inputAmplitude = hypot(ur, ui) * 2.0 / input->count;
    next.outputAmplitude = hypot(yr, yi) * 2.0 / input->count;
    if (next.inputAmplitude < input->minAmplitude)
    {
        return MC_ERR_EVIDENCE;
    }
    power = ur * ur + ui * ui;
    next.real = (yr * ur + yi * ui) / power;
    next.imaginary = (yi * ur - yr * ui) / power;
    next.magnitude = hypot(next.real, next.imaginary);
    next.phaseRad = atan2(next.imaginary, next.real);
    next.cycles = (uint32_t)rounded;
    if (!isfinite(next.magnitude) || !isfinite(next.phaseRad))
    {
        return MC_ERR_NUMBER;
    }
    *result = next;
    return MC_OK;
}

McStatus mc_phase_current(const McPhaseSample *sample, FocPhase *currentA)
{
    FocPhase next;
    double age, sum;
    if (sample == NULL || currentA == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!isfinite(sample->sampleTimeS) || !isfinite(sample->targetTimeS) ||
        !isfinite(sample->maxAgeS) || !isfinite(sample->maxZeroSumA))
    {
        return MC_ERR_NUMBER;
    }
    if (sample->validMask > 7u || sample->maxAgeS < 0.0f || sample->maxZeroSumA < 0.0f)
    {
        return MC_ERR_RANGE;
    }
    if (sample->validMask != 3u && sample->validMask != 5u && sample->validMask != 6u &&
        sample->validMask != 7u)
    {
        return MC_ERR_EVIDENCE;
    }
    age = sample->targetTimeS - sample->sampleTimeS;
    if (age < 0.0 || age > sample->maxAgeS)
    {
        return MC_ERR_STALE;
    }
    next = sample->currentA;
    if (((sample->validMask & 1u) != 0u && !isfinite(next.a)) ||
        ((sample->validMask & 2u) != 0u && !isfinite(next.b)) ||
        ((sample->validMask & 4u) != 0u && !isfinite(next.c)))
    {
        return MC_ERR_NUMBER;
    }
    switch (sample->validMask)
    {
        case 3u:
            next.c = -next.a - next.b;
            break;
        case 5u:
            next.b = -next.a - next.c;
            break;
        case 6u:
            next.a = -next.b - next.c;
            break;
        default:
            sum = (double)next.a + next.b + next.c;
            if (fabs(sum) > sample->maxZeroSumA)
            {
                return MC_ERR_CONSTRAINT;
            }
            break;
    }
    if (!finite_phase(next))
    {
        return MC_ERR_NUMBER;
    }
    *currentA = next;
    return MC_OK;
}

McStatus mc_bus_current(const McBusSample *first, const McBusSample *second,
                        const McShuntLimits *limits, McReconstructed *result)
{
    McReconstructed next;
    double age1, age2, errorBound;
    int a1, b1, a2, b2, determinant;
    if (first == NULL || second == NULL || limits == NULL || result == NULL)
    {
        return MC_ERR_NULL;
    }
    if (!first->valid || !second->valid)
    {
        return MC_ERR_SAMPLE;
    }
    if (!limits->slopeBoundValid)
    {
        return MC_ERR_EVIDENCE;
    }
    if (!isfinite(first->busCurrentA) || !isfinite(second->busCurrentA) ||
        !isfinite(first->sampleTimeS) || !isfinite(second->sampleTimeS) ||
        !isfinite(first->validWindowS) || !isfinite(second->validWindowS) ||
        !isfinite(limits->targetTimeS) || !isfinite(limits->minWindowS) ||
        !isfinite(limits->maxAgeS) || !isfinite(limits->maxSeparationS) ||
        !isfinite(limits->maxPhaseSlopeAS) || !isfinite(limits->maxErrorA))
    {
        return MC_ERR_NUMBER;
    }
    if (first->switchState < 1u || first->switchState > 6u || second->switchState < 1u ||
        second->switchState > 6u || limits->minWindowS <= 0.0f || limits->maxAgeS < 0.0f ||
        limits->maxSeparationS < 0.0f || limits->maxPhaseSlopeAS < 0.0f || limits->maxErrorA < 0.0f)
    {
        return MC_ERR_RANGE;
    }
    if (first->validWindowS < limits->minWindowS || second->validWindowS < limits->minWindowS)
    {
        return MC_ERR_CONSTRAINT;
    }
    age1 = limits->targetTimeS - first->sampleTimeS;
    age2 = limits->targetTimeS - second->sampleTimeS;
    if (age1 < 0.0 || age2 < 0.0 || age1 > limits->maxAgeS || age2 > limits->maxAgeS ||
        fabs(first->sampleTimeS - second->sampleTimeS) > limits->maxSeparationS)
    {
        return MC_ERR_STALE;
    }
    errorBound = limits->maxPhaseSlopeAS * (age1 + age2);
    if (errorBound > limits->maxErrorA)
    {
        return MC_ERR_CONSTRAINT;
    }
    /* 消去Ic=-Ia-Ib，系数只可能为-1/0/1；相同或互补向量均被秩检查拒绝 */
    a1 = (int)(first->switchState & 1u) - (int)((first->switchState >> 2u) & 1u);
    b1 = (int)((first->switchState >> 1u) & 1u) - (int)((first->switchState >> 2u) & 1u);
    a2 = (int)(second->switchState & 1u) - (int)((second->switchState >> 2u) & 1u);
    b2 = (int)((second->switchState >> 1u) & 1u) - (int)((second->switchState >> 2u) & 1u);
    determinant = a1 * b2 - a2 * b1;
    if (determinant == 0)
    {
        return MC_ERR_EVIDENCE;
    }
    next.currentA.a = (first->busCurrentA * b2 - second->busCurrentA * b1) / determinant;
    next.currentA.b = (a1 * second->busCurrentA - a2 * first->busCurrentA) / determinant;
    next.currentA.c = -next.currentA.a - next.currentA.b;
    next.errorBoundA = (float)errorBound;
    if (!finite_phase(next.currentA) || !isfinite(next.errorBoundA))
    {
        return MC_ERR_NUMBER;
    }
    *result = next;
    return MC_OK;
}
