/**
 * @file servo_validation.c
 * @brief 三条伺服纵向案例的 C99 宿主验证；所有对象和测量均为合成数据。
 * @author HU JIAXUAN
 * @date 2026-10-25
 *
 * 复用共享 PI、坐标变换和 SVPWM；本文件只拥有示例组合、独立对象和验收。
 * 不访问硬件。控制器用 float；真值对象、辨识和轨迹用 double。
 */
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pid_pi.h"
#include "foc_math.h"
#include "foc_svpwm.h"

#define PI_D (3.14159265358979323846)
#define PERIOD_S (0.00005)
#define MAX_CHECKS (96u)
#define DRIVE_DECOUPLE (1u)
#define DRIVE_DTC (2u)
#define DRIVE_AW (4u)

typedef enum
{
    SERVO_OK = 0,
    SERVO_ERR_INPUT = -1,
    SERVO_ERR_CALC = -2
} ServoStatus;
typedef struct
{
    const char *name;
    double observed;
    double threshold;
    bool passed;
    bool minimum;
} Metric;
typedef struct
{
    Metric metrics[MAX_CHECKS];
    size_t count;
    size_t failed;
    FILE *csv;
    bool ioFailed;
} Report;
typedef struct
{
    double resistanceOhm;
    double ldH;
    double lqH;
    double fluxWb;
    double polePairs;
    double inertiaKgm2;
    double viscousNms;
    double loadNm;
    double gravityNm;
} MotorConfig;
typedef struct
{
    MotorConfig config;
    double y[4]; /* Id[A], Iq[A], 机械位置[rad], 机械速度[rad/s]。 */
    bool lockedSpeed;
} Motor;
typedef struct
{
    PidPi piD;
    PidPi piQ;
    MotorConfig config;
    uint32_t flags;
} Drive;
typedef struct
{
    FocPhase phaseA;
    double busV;
    double thetaRad;
    double omegaRadS;
    double idRefA;
    double iqRefA;
} DriveInput;
typedef struct
{
    FocAb gateReqV;
    FocAb gateV;
    FocAb correctionV;
    FocDq piV;
    FocDq feedV;
    double idA;
    double iqA;
    double idRefA;
    double iqRefA;
    double busV;
    double dutyMin;
    double dutyMax;
    double residualV;
    double integralD;
    double integralQ;
    bool saturated;
} DriveOutput;
typedef struct
{
    const char *name;
    double timeS;
    double posRefRad;
    double velRefRadS;
    double accelRefRadS2;
    const Motor *motor;
    FocAb effectiveV;
    double velocityRequestRadS;
    double torqueFeedA;
} Trace;
typedef struct
{
    double xx;
    double xu;
    double uu;
    double xy;
    double uy;
} Fit;
typedef struct
{
    double resistanceOhm;
    double inductanceH;
} Identified;
typedef struct
{
    double p;
    double v;
    double a;
    double j;
} Motion;
typedef struct
{
    double b[6];
    double durationS;
    double elapsedS;
    double prefixS;
    double phaseS[4];
    double phaseJerk[4];
    Motion initial;
} Trajectory;
typedef struct
{
    double velocityRadS;
    double accelRadS2;
    double jerkRadS3;
} MotionLimits;
typedef struct
{
    double rmsError;
    double peakError;
    double peakCurrent;
    double settleS;
    double crossRms;
    double finalError;
    double dutyViolation;
    size_t saturatedTicks;
} Stats;

/* 文件私有原型集中；对象均由调用栈独占，没有 ISR、共享状态或动态分配。 */
static double clamp_value(double value, double lower, double upper);
static void check_metric(Report *report, const char *name, double value, double limit,
                         bool minimum);
static void write_trace(Report *report, const Trace *trace, const DriveOutput *output);
static MotorConfig motor_config(void);
static FocPhase motor_phase(const Motor *motor);
static void motor_rates(const Motor *motor, const double state[4], FocAb voltage, double rates[4]);
static ServoStatus motor_update(Motor *motor, FocAb voltage);
static FocAb inverter_apply(const Motor *motor, FocAb gateV, double busV, double lossRatio);
static void drive_init(Drive *drive, const MotorConfig *config, double bandwidthRadS,
                       uint32_t flags);
static ServoStatus drive_update(Drive *drive, const DriveInput *input, DriveOutput *output);
static double compensation_value(double currentA, double amplitudeV);
static void fit_add(Fit *fit, double currentA, double voltageV, double nextA);
static ServoStatus fit_solve(const Fit *fit, double periodS, Identified *identified);
static double ident_run(double resistanceOhm, double inductanceH, Identified *identified);
static ServoStatus current_run(Report *report, const MotorConfig *truth,
                               const MotorConfig *estimate, uint32_t flags, Stats *stats);
static void case_ident(Report *report);
static double bezier_value(const double *points, size_t count, double fraction);
static Motion trajectory_get(const Trajectory *trajectory, double elapsedS);
static Motion motion_jerk(Motion start, double durationS, double jerkRadS3);
static ServoStatus trajectory_curve(const Motion *start, double targetRad,
                                    const MotionLimits *limits, Trajectory *trajectory);
static ServoStatus trajectory_plan(const Motion *start, double targetRad,
                                   const MotionLimits *limits, Trajectory *trajectory);
static void trajectory_events(double timeS, double *targetRad, bool *changed);
static ServoStatus motion_run(Report *report, bool feedforward, Stats *stats);
static void case_motion(Report *report);
static ServoStatus inverter_run(Report *report, uint32_t flags, bool saturating, Stats *stats);
static void case_inverter(Report *report);
static void case_invalid(Report *report);
static int write_report(const Report *report);

/** @brief 夹紧标量，边界由内部调用方预先保证有序。 */
static double clamp_value(double value, double lower, double upper)
{
    /* 不改变输入的单位。 */
    return fmax(lower, fmin(upper, value));
}

/** @brief 记录有限数值验收，任何 NaN/Inf 或越限都产生失败。 */
static void check_metric(Report *report, const char *name, double value, double limit, bool minimum)
{
    Metric item = {name, value, limit, false, minimum};
    /* 固定容量失败也必须传递到进程退出码。 */
    item.passed = isfinite(value) && (minimum ? value >= limit : value <= limit);
    if (report->count >= MAX_CHECKS)
    {
        report->failed++;
        return;
    }
    report->metrics[report->count++] = item;
    if (!item.passed)
    {
        report->failed++;
        (void)fprintf(stderr, "FAIL %s: %.9g %s %.9g\n", name, value, minimum ? "<" : ">", limit);
    }
}

/** @brief 抽取宿主观测，不在被测控制原语中加入日志。 */
static void write_trace(Report *report, const Trace *trace, const DriveOutput *output)
{
    /* 门极电压与含逆变器误差的端电压分别保存，不能混作硬件实测。 */
    int result = fprintf(
        report->csv,
        "%s,%.8f,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,"
        "%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%d,%.9g,%.9g\n",
        trace->name, trace->timeS, trace->posRefRad, trace->motor->y[2], trace->velRefRadS,
        trace->motor->y[3], trace->accelRefRadS2, output->idRefA, output->idA, output->iqRefA,
        output->iqA, output->busV, (double)output->piV.d, (double)output->piV.q,
        (double)output->feedV.d, (double)output->feedV.q, (double)output->correctionV.alpha,
        (double)output->correctionV.beta, (double)output->gateReqV.alpha,
        (double)output->gateReqV.beta, (double)output->gateV.alpha, (double)output->gateV.beta,
        output->residualV, (double)trace->effectiveV.alpha, (double)trace->effectiveV.beta,
        output->integralD, output->integralQ, output->saturated ? 1 : 0, trace->velocityRequestRadS,
        trace->torqueFeedA);
    if (result < 0)
    {
        report->ioFailed = true;
    }
}

/** @brief 给出一套明确的合成 PMSM 参数，非通用电机默认值。 */
static MotorConfig motor_config(void)
{
    /* 额定值不代表任何真实设备；Kt=1.5*p*psi=0.12 Nm/A。 */
    MotorConfig config = {0.55, 0.0015, 0.0023, 0.02, 4.0, 0.002, 0.001, 0.0, 0.0};
    return config;
}

/** @brief 从真值 dq 电流独立生成三相合成测量。 */
static FocPhase motor_phase(const Motor *motor)
{
    double angle = motor->config.polePairs * motor->y[2];
    double alpha = motor->y[0] * cos(angle) - motor->y[1] * sin(angle);
    double beta = motor->y[0] * sin(angle) + motor->y[1] * cos(angle);
    /* 显式三相定义与控制器变换实现分开，使用幅值不变标度。 */
    FocPhase phase = {(float)alpha, (float)(-0.5 * alpha + sqrt(3.0) * 0.5 * beta),
                      (float)(-0.5 * alpha - sqrt(3.0) * 0.5 * beta)};
    return phase;
}

/** @brief 双精度电气和机械连续对象，不复用控制器补偿函数。 */
static void motor_rates(const Motor *motor, const double state[4], FocAb voltage, double rates[4])
{
    const MotorConfig *config = &motor->config;
    double angle = config->polePairs * state[2];
    double omega = config->polePairs * state[3];
    double vd = voltage.alpha * cos(angle) + voltage.beta * sin(angle);
    double vq = -voltage.alpha * sin(angle) + voltage.beta * cos(angle);
    double torque = 1.5 * config->polePairs *
                    (config->fluxWb * state[1] + (config->ldH - config->lqH) * state[0] * state[1]);
    /* 电压和反电势单位为 V，机械轴单位为 rad / rad/s。 */
    rates[0] =
        (vd - config->resistanceOhm * state[0] + omega * config->lqH * state[1]) / config->ldH;
    rates[1] = (vq - config->resistanceOhm * state[1] -
                omega * (config->ldH * state[0] + config->fluxWb)) /
               config->lqH;
    rates[2] = state[3];
    rates[3] = motor->lockedSpeed ? 0.0
                                  : (torque - config->viscousNms * state[3] - config->loadNm -
                                     config->gravityNm * sin(state[2])) /
                                        config->inertiaKgm2;
}

/** @brief 使用四个子步 RK4 积分，端电压在一个 PWM 周期保持。 */
static ServoStatus motor_update(Motor *motor, FocAb voltage)
{
    size_t substep;
    /* RK4 与辨识器的精确离散 RL 递推采用不同数值路径。 */
    for (substep = 0u; substep < 4u; substep++)
    {
        double k1[4], k2[4], k3[4], k4[4], temporary[4];
        double h = PERIOD_S / 4.0;
        size_t index;
        motor_rates(motor, motor->y, voltage, k1);
        for (index = 0u; index < 4u; index++)
        {
            temporary[index] = motor->y[index] + h * k1[index] / 2.0;
        }
        motor_rates(motor, temporary, voltage, k2);
        for (index = 0u; index < 4u; index++)
        {
            temporary[index] = motor->y[index] + h * k2[index] / 2.0;
        }
        motor_rates(motor, temporary, voltage, k3);
        for (index = 0u; index < 4u; index++)
        {
            temporary[index] = motor->y[index] + h * k3[index];
        }
        motor_rates(motor, temporary, voltage, k4);
        for (index = 0u; index < 4u; index++)
        {
            motor->y[index] +=
                h * (k1[index] + 2.0 * k2[index] + 2.0 * k3[index] + k4[index]) / 6.0;
            if (!isfinite(motor->y[index]))
            {
                return SERVO_ERR_CALC;
            }
        }
    }
    return SERVO_OK;
}

/** @brief 独立逆变器真值：用 atan 电流过零模型描述有效端电压损失。 */
static FocAb inverter_apply(const Motor *motor, FocAb gateV, double busV, double lossRatio)
{
    FocPhase phase = motor_phase(motor);
    double lossA = busV * lossRatio * (2.0 / PI_D) * atan(phase.a / 0.025);
    double lossB = busV * lossRatio * (2.0 / PI_D) * atan(phase.b / 0.025);
    double lossC = busV * lossRatio * (2.0 / PI_D) * atan(phase.c / 0.025);
    /* 共模分量不施加到无中性线电机，真值不用控制器补偿的代数函数。 */
    FocAb voltage = {(float)(gateV.alpha - (2.0 * lossA - lossB - lossC) / 3.0),
                     (float)(gateV.beta - (lossB - lossC) / sqrt(3.0))};
    return voltage;
}

/** @brief 初始化共享轻量 PI，配置和状态只属于本轴实例。 */
static void drive_init(Drive *drive, const MotorConfig *config, double bandwidthRadS,
                       uint32_t flags)
{
    /* 大的单轴 PI 上限用于保留独立积分上限；总电压仍由母线实际约束。 */
    memset(drive, 0, sizeof(*drive));
    drive->config = *config;
    drive->flags = flags;
    drive->piD.kp = (float)(config->ldH * bandwidthRadS);
    drive->piD.ki = (float)(config->resistanceOhm * bandwidthRadS);
    drive->piQ.kp = (float)(config->lqH * bandwidthRadS);
    drive->piQ.ki = (float)(config->resistanceOhm * bandwidthRadS);
}

/** @brief 连续、奇对称的补偿函数，幅值 V，过零平滑尺度为 0.045 A。 */
static double compensation_value(double currentA, double amplitudeV)
{
    /* 不用 sign() 硬切换，避免测量微小波动造成全幅极性跳变。 */
    return amplitudeV * currentA / sqrt(currentA * currentA + 0.045 * 0.045);
}

/**
 * @brief 组合一拍电流控制、补偿、最终调制及同一评价点回算。
 * @param[in,out] drive 独占控制器，失败时不修改。
 * @param[in] input 同一采样周期的电流、角度、速度及请求；不能为空。
 * @param[out] output 成功时才发布的门极请求和观测；不能为空且不与 drive 重叠。
 * @return SERVO_OK 或输入/数值错误；没有硬件副作用。
 */
static ServoStatus drive_update(Drive *drive, const DriveInput *input, DriveOutput *output)
{
    Drive next;
    DriveOutput result = {0};
    PidPiStep stepD, stepQ;
    FocSinCos sc;
    FocDq measured, total, residual;
    FocAb base, correction, applied, difference;
    FocSvpwm pwm;
    double limit, magnitude, scale, common;
    double dutyA, dutyB, dutyC, lossA, lossB, lossC;
    double trackD, trackQ;
    if (drive == NULL || input == NULL || output == NULL || !isfinite(input->busV) ||
        input->busV <= 0.0 || !isfinite(input->thetaRad) || !isfinite(input->omegaRadS) ||
        !isfinite(input->idRefA) || !isfinite(input->iqRefA) || !isfinite(input->phaseA.a) ||
        !isfinite(input->phaseA.b) || !isfinite(input->phaseA.c))
    {
        return SERVO_ERR_INPUT;
    }
    /* 原对象在两个 PI 都成功跟踪前不改变，避免半更新状态。 */
    next = *drive;
    sc = foc_sincos((float)input->thetaRad);
    measured = foc_park(foc_clarke(input->phaseA), sc);
    if (pid_pi_eval(&next.piD, (float)(input->idRefA - measured.d), (float)PERIOD_S, 100.0f,
                    &stepD) != PID_OK ||
        pid_pi_eval(&next.piQ, (float)(input->iqRefA - measured.q), (float)PERIOD_S, 100.0f,
                    &stepQ) != PID_OK)
    {
        return SERVO_ERR_CALC;
    }
    if ((drive->flags & DRIVE_DECOUPLE) != 0u)
    {
        result.feedV.d = (float)(-input->omegaRadS * drive->config.lqH * measured.q);
        result.feedV.q =
            (float)(input->omegaRadS * (drive->config.ldH * measured.d + drive->config.fluxWb));
    }
    total.d = stepD.output + result.feedV.d;
    total.q = stepQ.output + result.feedV.q;
    base = foc_inv_park(total, sc);
    lossA = compensation_value(input->phaseA.a, input->busV * 0.025);
    lossB = compensation_value(input->phaseA.b, input->busV * 0.025);
    lossC = compensation_value(input->phaseA.c, input->busV * 0.025);
    correction.alpha = (float)((2.0 * lossA - lossB - lossC) / 3.0);
    correction.beta = (float)((lossB - lossC) / sqrt(3.0));
    if ((drive->flags & DRIVE_DTC) == 0u)
    {
        correction = (FocAb){0.0f, 0.0f};
    }
    result.gateReqV = (FocAb){base.alpha + correction.alpha, base.beta + correction.beta};
    limit = 0.94 * input->busV / sqrt(3.0);
    magnitude = hypot(result.gateReqV.alpha, result.gateReqV.beta);
    scale = magnitude > limit ? limit / magnitude : 1.0;
    if (!foc_svpwm_init(&pwm))
    {
        return SERVO_ERR_CALC;
    }
    pwm.config.maxModulation = (float)(0.94 / sqrt(3.0));
    pwm.input.modulation.alpha = (float)(result.gateReqV.alpha * scale / input->busV);
    pwm.input.modulation.beta = (float)(result.gateReqV.beta * scale / input->busV);
    if (!foc_svpwm(&pwm))
    {
        return SERVO_ERR_CALC;
    }
    dutyA = pwm.state.dutyA;
    dutyB = pwm.state.dutyB;
    dutyC = pwm.state.dutyC;
    common = (dutyA + dutyB + dutyC) / 3.0;
    applied.alpha = (float)(input->busV * (dutyA - common));
    applied.beta = (float)(input->busV * (dutyB - dutyC) / sqrt(3.0));
    difference =
        (FocAb){applied.alpha - result.gateReqV.alpha, applied.beta - result.gateReqV.beta};
    residual = foc_park(difference, sc);
    /* 补偿本身不是饱和；只将最终门极约束残差映射回原 PI 评价点。 */
    trackD = stepD.output + residual.d;
    trackQ = stepQ.output + residual.q;
    if ((drive->flags & DRIVE_AW) != 0u)
    {
        if (pid_pi_track(&next.piD, &stepD, (float)trackD) != PID_OK ||
            pid_pi_track(&next.piQ, &stepQ, (float)trackQ) != PID_OK)
        {
            return SERVO_ERR_CALC;
        }
    }
    else
    {
        next.piD.integral = stepD.integral;
        next.piQ.integral = stepQ.integral;
    }
    result.gateV = applied;
    result.correctionV = correction;
    result.piV = (FocDq){stepD.output, stepQ.output};
    result.idA = measured.d;
    result.iqA = measured.q;
    result.idRefA = input->idRefA;
    result.iqRefA = input->iqRefA;
    result.busV = input->busV;
    result.dutyMin = fmin(dutyA, fmin(dutyB, dutyC));
    result.dutyMax = fmax(dutyA, fmax(dutyB, dutyC));
    result.residualV = hypot(difference.alpha, difference.beta);
    result.integralD = next.piD.integral;
    result.integralQ = next.piQ.integral;
    result.saturated = scale < 0.999999 || pwm.state.saturated;
    *drive = next;
    *output = result;
    return SERVO_OK;
}

/** @brief 累积二参数离散 RL 最小二乘的充分统计量。 */
static void fit_add(Fit *fit, double currentA, double voltageV, double nextA)
{
    /* 激励与测量由调用方提供，求解器不知道真值 R/L。 */
    fit->xx += currentA * currentA;
    fit->xu += currentA * voltageV;
    fit->uu += voltageV * voltageV;
    fit->xy += currentA * nextA;
    fit->uy += voltageV * nextA;
}

/** @brief 从 i[k+1]=a*i[k]+b*u[k] 求 R/L；奇异激励不发布结果。 */
static ServoStatus fit_solve(const Fit *fit, double periodS, Identified *identified)
{
    Identified candidate;
    double determinant, a, b;
    if (fit == NULL || identified == NULL || !isfinite(periodS) || periodS <= 0.0)
    {
        return SERVO_ERR_INPUT;
    }
    determinant = fit->xx * fit->uu - fit->xu * fit->xu;
    if (!isfinite(determinant) || determinant <= 1.0e-12)
    {
        return SERVO_ERR_CALC;
    }
    /* 精确 ZOH 关系，区别于用连续欧拉斜率拟合。 */
    a = (fit->xy * fit->uu - fit->uy * fit->xu) / determinant;
    b = (fit->uy * fit->xx - fit->xy * fit->xu) / determinant;
    if (!isfinite(a) || !isfinite(b) || a <= 0.0 || a >= 1.0 || b <= 0.0)
    {
        return SERVO_ERR_CALC;
    }
    candidate.resistanceOhm = (1.0 - a) / b;
    candidate.inductanceH = -candidate.resistanceOhm * periodS / log(a);
    if (!isfinite(candidate.inductanceH) || candidate.inductanceH <= 0.0)
    {
        return SERVO_ERR_CALC;
    }
    *identified = candidate;
    return SERVO_OK;
}

/** @brief 用带确定性噪声的训练数据辨识，再在不同激励和初值下验证。 */
static double ident_run(double resistanceOhm, double inductanceH, Identified *identified)
{
    Fit fit = {0};
    double currentA = -1.7;
    double pole = exp(-resistanceOhm * PERIOD_S / inductanceH);
    double squared = 0.0, predictedA = 2.3;
    size_t index;
    for (index = 0u; index < 4000u; index++)
    {
        double voltageV =
            ((index / 17u) % 2u == 0u ? 2.7 : -1.8) + 0.8 * sin(0.137 * (double)index);
        double nextA = pole * currentA + (1.0 - pole) * voltageV / resistanceOhm;
        /* 测量噪声峰值 0.2 mA；不是实际 ADC/逆变器校准数据。 */
        fit_add(&fit, currentA + 0.0002 * sin(0.91 * (double)index), voltageV,
                nextA + 0.0002 * sin(0.91 * (double)(index + 1u)));
        currentA = nextA;
    }
    if (fit_solve(&fit, PERIOD_S, identified) != SERVO_OK)
    {
        return NAN;
    }
    currentA = 2.3;
    for (index = 0u; index < 2000u; index++)
    {
        double voltageV = 1.4 * sin(0.043 * (double)index) + 0.7 * cos(0.317 * (double)index);
        double nextA = pole * currentA + (1.0 - pole) * voltageV / resistanceOhm;
        double estimatedPole = exp(-identified->resistanceOhm * PERIOD_S / identified->inductanceH);
        /* 留出段自由递推，不在每拍用真值电流重置预测状态。 */
        predictedA = estimatedPole * predictedA +
                     (1.0 - estimatedPole) * voltageV / identified->resistanceOhm;
        squared += (predictedA - nextA) * (predictedA - nextA);
        currentA = nextA;
    }
    return sqrt(squared / 2000.0);
}

/** @brief 运行一拍输出延迟的 PMSM 电流环，比较解耦开关。 */
static ServoStatus current_run(Report *report, const MotorConfig *truth,
                               const MotorConfig *estimate, uint32_t flags, Stats *stats)
{
    Motor motor = {*truth, {0.7, -0.5, 0.0, 150.0}, true};
    Drive drive;
    DriveOutput output;
    FocAb pending = {0.0f, 0.0f};
    double squared = 0.0;
    size_t index, samples = 0u;
    memset(stats, 0, sizeof(*stats));
    drive_init(&drive, estimate, 1000.0, flags);
    for (index = 0u; index < 4000u; index++)
    {
        double timeS = (double)index * PERIOD_S;
        DriveInput input = {
            motor_phase(&motor),           48.0, truth->polePairs * motor.y[2],
            truth->polePairs * motor.y[3], 0.0,  timeS < 0.04 ? 0.0 : (timeS < 0.12 ? 3.0 : -2.0)};
        FocAb applied = pending;
        if (drive_update(&drive, &input, &output) != SERVO_OK)
        {
            return SERVO_ERR_CALC;
        }
        pending = output.gateV;
        /* 仅统计阶跃后的固定窗口；正反电流和非零初值都进入对象。 */
        if ((timeS >= 0.04 && timeS < 0.09) || (timeS >= 0.12 && timeS < 0.17))
        {
            squared += motor.y[0] * motor.y[0];
            samples++;
        }
        if (index >= 3600u)
        {
            stats->finalError = fmax(stats->finalError, fabs(motor.y[1] + 2.0));
        }
        if (index % 20u == 0u)
        {
            Trace trace = {(flags & DRIVE_DECOUPLE) != 0u ? "identified_decoupled"
                                                          : "identified_baseline",
                           timeS,
                           0.0,
                           0.0,
                           0.0,
                           &motor,
                           applied,
                           0.0,
                           0.0};
            write_trace(report, &trace, &output);
        }
        if (motor_update(&motor, applied) != SERVO_OK)
        {
            return SERVO_ERR_CALC;
        }
    }
    stats->crossRms = sqrt(squared / (double)samples);
    return SERVO_OK;
}

/** @brief 三组真值、多初值、训练留出数据及解耦 A/B 验收。 */
static void case_ident(Report *report)
{
    MotorConfig truth = motor_config();
    MotorConfig identifiedConfig = truth;
    double maxRError = 0.0, maxLError = 0.0, maxHoldout = 0.0;
    size_t index;
    Stats baseline, compensated;
    for (index = 0u; index < 3u; index++)
    {
        Identified d = {0}, q = {0};
        double resistance = 0.4 + 0.15 * (double)index;
        double ld = 0.0012 + 0.0003 * (double)index;
        double lq = 0.002 + 0.0003 * (double)index;
        double dRmse = ident_run(resistance, ld, &d);
        double qRmse = ident_run(resistance, lq, &q);
        maxRError = fmax(maxRError, fmax(fabs(d.resistanceOhm / resistance - 1.0),
                                         fabs(q.resistanceOhm / resistance - 1.0)));
        maxLError =
            fmax(maxLError, fmax(fabs(d.inductanceH / ld - 1.0), fabs(q.inductanceH / lq - 1.0)));
        maxHoldout = fmax(maxHoldout, fmax(dRmse, qRmse));
        if (index == 1u)
        {
            identifiedConfig.resistanceOhm = 0.5 * (d.resistanceOhm + q.resistanceOhm);
            identifiedConfig.ldH = d.inductanceH;
            identifiedConfig.lqH = q.inductanceH;
        }
    }
    check_metric(report, "identification.max_R_relative_error", maxRError, 0.02, false);
    check_metric(report, "identification.max_L_relative_error", maxLError, 0.02, false);
    check_metric(report, "identification.holdout_current_rmse_A", maxHoldout, 0.01, false);
    /* 控制器用估计值；对象保留独立真值，不能把拟合值当电机。 */
    if (current_run(report, &truth, &identifiedConfig, DRIVE_AW, &baseline) != SERVO_OK ||
        current_run(report, &truth, &identifiedConfig, DRIVE_AW | DRIVE_DECOUPLE, &compensated) !=
            SERVO_OK)
    {
        check_metric(report, "identification.current_execution", 1.0, 0.0, false);
        return;
    }
    check_metric(report, "identification.cross_baseline_rms_A", baseline.crossRms, 10.0, false);
    check_metric(report, "identification.cross_decoupled_rms_A", compensated.crossRms, 0.08, false);
    check_metric(report, "identification.cross_rms_ratio", compensated.crossRms / baseline.crossRms,
                 0.5, false);
    check_metric(report, "identification.final_iq_error_A", compensated.finalError, 0.02, false);
}

/** @brief de Casteljau 求值，固定小数组，不使用 VLA 或动态分配。 */
static double bezier_value(const double *points, size_t count, double fraction)
{
    double temporary[6];
    size_t level, index;
    /* 内部调用 count 固定在 3..6。 */
    for (index = 0u; index < count; index++)
    {
        temporary[index] = points[index];
    }
    for (level = count - 1u; level > 0u; level--)
    {
        for (index = 0u; index < level; index++)
        {
            temporary[index] =
                (1.0 - fraction) * temporary[index] + fraction * temporary[index + 1u];
        }
    }
    return temporary[0];
}

/** @brief 返回边界匹配五次轨迹的 p/v/a/j；段外钳位到端点。 */
static Motion trajectory_get(const Trajectory *trajectory, double elapsedS)
{
    double v[5], a[4], j[3];
    double fraction;
    Motion result;
    size_t index;
    /* 可选前缀先将加速度回零，再执行三段有界 jerk 制动。 */
    result = trajectory->initial;
    for (index = 0u; index < 4u; index++)
    {
        if (elapsedS < trajectory->phaseS[index])
        {
            return motion_jerk(result, fmax(0.0, elapsedS), trajectory->phaseJerk[index]);
        }
        result = motion_jerk(result, trajectory->phaseS[index], trajectory->phaseJerk[index]);
        elapsedS -= trajectory->phaseS[index];
    }
    fraction = clamp_value(elapsedS / trajectory->durationS, 0.0, 1.0);
    /* 导数控制点是解析值，前馈不对有噪声的反馈位置差分。 */
    for (index = 0u; index < 5u; index++)
    {
        v[index] = 5.0 * (trajectory->b[index + 1u] - trajectory->b[index]) / trajectory->durationS;
    }
    for (index = 0u; index < 4u; index++)
    {
        a[index] = 4.0 * (v[index + 1u] - v[index]) / trajectory->durationS;
    }
    for (index = 0u; index < 3u; index++)
    {
        j[index] = 3.0 * (a[index + 1u] - a[index]) / trajectory->durationS;
    }
    result.p = bezier_value(trajectory->b, 6u, fraction);
    result.v = bezier_value(v, 5u, fraction);
    result.a = bezier_value(a, 4u, fraction);
    result.j = elapsedS > trajectory->durationS ? 0.0 : bezier_value(j, 3u, fraction);
    return result;
}

/** @brief 常 jerk 段的解析运动学积分，使用 s、rad、rad/s 物理量。 */
static Motion motion_jerk(Motion start, double durationS, double jerkRadS3)
{
    Motion result;
    /* 每一段都继承上一段 p/v/a，jerk 在边界允许跳变。 */
    result.p = start.p + start.v * durationS + start.a * durationS * durationS / 2.0 +
               jerkRadS3 * durationS * durationS * durationS / 6.0;
    result.v = start.v + start.a * durationS + jerkRadS3 * durationS * durationS / 2.0;
    result.a = start.a + jerkRadS3 * durationS;
    result.j = jerkRadS3;
    return result;
}

/** @brief 有界搜索满足全程导数凸包约束的五次段。 */
static ServoStatus trajectory_curve(const Motion *start, double targetRad,
                                    const MotionLimits *limits, Trajectory *trajectory)
{
    size_t attempt;
    double durationS = 0.02;
    /* 非零 a 初态不保证任意长时长可行，故检查每个候选而非假设单调可行性。 */
    for (attempt = 0u; attempt < 120u; attempt++)
    {
        Trajectory candidate = *trajectory;
        double v[5], a[4], j[3];
        bool feasible = true;
        size_t index;
        candidate.durationS = durationS;
        candidate.elapsedS = 0.0;
        candidate.b[0] = start->p;
        candidate.b[1] = start->p + start->v * durationS / 5.0;
        candidate.b[2] =
            start->p + 2.0 * start->v * durationS / 5.0 + start->a * durationS * durationS / 20.0;
        candidate.b[3] = targetRad;
        candidate.b[4] = targetRad;
        candidate.b[5] = targetRad;
        for (index = 0u; index < 5u; index++)
        {
            v[index] = 5.0 * (candidate.b[index + 1u] - candidate.b[index]) / durationS;
            feasible = feasible && fabs(v[index]) <= limits->velocityRadS;
        }
        for (index = 0u; index < 4u; index++)
        {
            a[index] = 4.0 * (v[index + 1u] - v[index]) / durationS;
            feasible = feasible && fabs(a[index]) <= limits->accelRadS2;
        }
        for (index = 0u; index < 3u; index++)
        {
            j[index] = 3.0 * (a[index + 1u] - a[index]) / durationS;
            feasible = feasible && fabs(j[index]) <= limits->jerkRadS3;
        }
        if (feasible)
        {
            *trajectory = candidate;
            return SERVO_OK;
        }
        durationS *= 1.08;
    }
    return SERVO_ERR_CALC;
}

/** @brief 匹配 p/v/a 重规划；必要时先有界制动，失败不修改旧段。 */
static ServoStatus trajectory_plan(const Motion *start, double targetRad,
                                   const MotionLimits *limits, Trajectory *trajectory)
{
    Trajectory candidate = {0};
    Motion stopped;
    double direction, peakAccel, jerkTime;
    size_t index;
    if (start == NULL || limits == NULL || trajectory == NULL || !isfinite(targetRad) ||
        !isfinite(start->p) || !isfinite(start->v) || !isfinite(start->a) ||
        !isfinite(limits->velocityRadS) || !isfinite(limits->accelRadS2) ||
        !isfinite(limits->jerkRadS3) || limits->velocityRadS <= 0.0 || limits->accelRadS2 <= 0.0 ||
        limits->jerkRadS3 <= 0.0 || fabs(start->v) > limits->velocityRadS ||
        fabs(start->a) > limits->accelRadS2)
    {
        return SERVO_ERR_INPUT;
    }
    candidate.initial = *start;
    if (trajectory_curve(start, targetRad, limits, &candidate) == SERVO_OK)
    {
        *trajectory = candidate;
        return SERVO_OK;
    }
    /* 直接五次段受凸包充分条件限制时，先中和初始 a，再三段制动到静止。 */
    candidate.phaseS[0] = fabs(start->a) / limits->jerkRadS3;
    candidate.phaseJerk[0] = start->a >= 0.0 ? -limits->jerkRadS3 : limits->jerkRadS3;
    stopped = motion_jerk(*start, candidate.phaseS[0], candidate.phaseJerk[0]);
    if (fabs(stopped.v) > limits->velocityRadS)
    {
        return SERVO_ERR_CALC;
    }
    direction = stopped.v >= 0.0 ? 1.0 : -1.0;
    peakAccel = fmin(limits->accelRadS2, sqrt(fabs(stopped.v) * limits->jerkRadS3));
    jerkTime = peakAccel / limits->jerkRadS3;
    candidate.phaseS[1] = jerkTime;
    candidate.phaseJerk[1] = -direction * limits->jerkRadS3;
    candidate.phaseS[2] = peakAccel > 0.0 ? fmax(0.0, fabs(stopped.v) / peakAccel - jerkTime) : 0.0;
    candidate.phaseJerk[2] = 0.0;
    candidate.phaseS[3] = jerkTime;
    candidate.phaseJerk[3] = direction * limits->jerkRadS3;
    for (index = 1u; index < 4u; index++)
    {
        stopped = motion_jerk(stopped, candidate.phaseS[index], candidate.phaseJerk[index]);
    }
    for (index = 0u; index < 4u; index++)
    {
        candidate.prefixS += candidate.phaseS[index];
    }
    stopped.v = 0.0;
    stopped.a = 0.0;
    if (trajectory_curve(&stopped, targetRad, limits, &candidate) != SERVO_OK)
    {
        return SERVO_ERR_CALC;
    }
    *trajectory = candidate;
    return SERVO_OK;
}

/** @brief 两次 A/B 都使用同一组绝对时间目标事件。 */
static void trajectory_events(double timeS, double *targetRad, bool *changed)
{
    /* 中途更改目标时 v/a 非零，随后覆盖反向和短行程。 */
    *changed = true;
    if (fabs(timeS) < PERIOD_S / 2.0)
    {
        *targetRad = 0.8;
    }
    else if (fabs(timeS - 0.35) < PERIOD_S / 2.0)
    {
        *targetRad = -0.25;
    }
    else if (fabs(timeS - 2.2) < PERIOD_S / 2.0)
    {
        *targetRad = -0.24;
    }
    else if (fabs(timeS - 3.0) < PERIOD_S / 2.0)
    {
        *targetRad = 0.55;
    }
    else
    {
        *changed = false;
    }
}

/** @brief 相同增益、母线、初值和负载的三环对象，只切换运动前馈。 */
static ServoStatus motion_run(Report *report, bool feedforward, Stats *stats)
{
    MotorConfig config = motor_config();
    Motor motor;
    Drive drive;
    PidPi speedPi = {3.0f, 166.6666667f, 0.0f};
    FocAb pending = {0.0f, 0.0f};
    Trajectory trajectory = {0};
    Motion reference = {0};
    MotionLimits limits = {2.5, 10.0, 100.0};
    DriveOutput output;
    double iqRequest = 0.0, targetRad = 0.0, squared = 0.0, lastOutsideS = 0.0, finalEndS = 6.0;
    double velocityRequest = 0.0, torqueFeedA = 0.0;
    double maxVelocity = 0.0, maxAccel = 0.0, maxJerk = 0.0, continuity = 0.0;
    double posDerivativeError = 0.0, velDerivativeError = 0.0;
    Motion previousRef = {0};
    size_t index;
    memset(stats, 0, sizeof(*stats));
    trajectory.durationS = 1.0;
    config.lqH = config.ldH;
    config.loadNm = 0.02;
    config.gravityNm = 0.035;
    motor = (Motor){config, {0.0, 0.0, 0.0, 0.0}, false};
    drive_init(&drive, &config, 1200.0, DRIVE_AW | DRIVE_DECOUPLE);
    for (index = 0u; index < 120000u; index++)
    {
        double timeS = (double)index * PERIOD_S;
        bool changed;
        FocAb applied = pending;
        reference = trajectory_get(&trajectory, trajectory.elapsedS);
        trajectory_events(timeS, &targetRad, &changed);
        if (changed)
        {
            Motion before = reference;
            if (trajectory_plan(&before, targetRad, &limits, &trajectory) != SERVO_OK)
            {
                return SERVO_ERR_CALC;
            }
            reference = trajectory_get(&trajectory, 0.0);
            continuity = fmax(continuity, fabs(reference.p - before.p));
            continuity = fmax(continuity, fabs(reference.v - before.v));
            continuity = fmax(continuity, fabs(reference.a - before.a));
            if (fabs(timeS - 3.0) < PERIOD_S / 2.0)
            {
                finalEndS = timeS + trajectory.prefixS + trajectory.durationS;
            }
        }
        reference = trajectory_get(&trajectory, trajectory.elapsedS);
        maxVelocity = fmax(maxVelocity, fabs(reference.v));
        maxAccel = fmax(maxAccel, fabs(reference.a));
        maxJerk = fmax(maxJerk, fabs(reference.j));
        if (index > 0u)
        {
            posDerivativeError =
                fmax(posDerivativeError, fabs((reference.p - previousRef.p) / PERIOD_S -
                                              0.5 * (reference.v + previousRef.v)));
            velDerivativeError =
                fmax(velDerivativeError, fabs((reference.v - previousRef.v) / PERIOD_S -
                                              0.5 * (reference.a + previousRef.a)));
        }
        previousRef = reference;
        if (index % 20u == 0u)
        {
            PidPiStep speedStep;
            velocityRequest = 20.0 * (reference.p - motor.y[2]) + (feedforward ? reference.v : 0.0);
            torqueFeedA =
                feedforward ? (config.inertiaKgm2 * reference.a + config.viscousNms * reference.v +
                               config.gravityNm * sin(reference.p)) /
                                  0.12
                            : 0.0;
            if (pid_pi_eval(&speedPi, (float)(velocityRequest - motor.y[3]), 0.001f, 6.0f,
                            &speedStep) != PID_OK)
            {
                return SERVO_ERR_CALC;
            }
            iqRequest = clamp_value(speedStep.output + torqueFeedA, -6.0, 6.0);
            if (pid_pi_track(&speedPi, &speedStep, (float)(iqRequest - torqueFeedA)) != PID_OK)
            {
                return SERVO_ERR_CALC;
            }
        }
        {
            DriveInput input = {motor_phase(&motor),           48.0, config.polePairs * motor.y[2],
                                config.polePairs * motor.y[3], 0.0,  iqRequest};
            if (drive_update(&drive, &input, &output) != SERVO_OK)
            {
                return SERVO_ERR_CALC;
            }
        }
        pending = output.gateV;
        squared += (reference.p - motor.y[2]) * (reference.p - motor.y[2]);
        stats->peakError = fmax(stats->peakError, fabs(reference.p - motor.y[2]));
        stats->peakCurrent = fmax(stats->peakCurrent, hypot(motor.y[0], motor.y[1]));
        if (timeS >= finalEndS && (fabs(motor.y[2] - 0.55) > 0.001 || fabs(motor.y[3]) > 0.01))
        {
            lastOutsideS = timeS;
        }
        if (index % 20u == 0u)
        {
            Trace trace = {feedforward ? "motion_ff" : "motion_baseline",
                           timeS,
                           reference.p,
                           reference.v,
                           reference.a,
                           &motor,
                           applied,
                           velocityRequest,
                           torqueFeedA};
            write_trace(report, &trace, &output);
        }
        if (motor_update(&motor, applied) != SERVO_OK)
        {
            return SERVO_ERR_CALC;
        }
        trajectory.elapsedS += PERIOD_S;
    }
    stats->rmsError = sqrt(squared / 120000.0);
    stats->settleS = fmax(0.0, lastOutsideS - finalEndS + PERIOD_S);
    stats->finalError = fabs(motor.y[2] - 0.55);
    if (feedforward)
    {
        check_metric(report, "motion.max_reference_velocity_rad_s", maxVelocity,
                     limits.velocityRadS, false);
        check_metric(report, "motion.max_reference_accel_rad_s2", maxAccel, limits.accelRadS2,
                     false);
        check_metric(report, "motion.max_reference_jerk_rad_s3", maxJerk, limits.jerkRadS3, false);
        check_metric(report, "motion.replan_C2_discontinuity", continuity, 1.0e-10, false);
        check_metric(report, "motion.position_derivative_error_rad_s", posDerivativeError, 1.0e-5,
                     false);
        check_metric(report, "motion.velocity_derivative_error_rad_s2", velDerivativeError, 0.003,
                     false);
        check_metric(report, "motion.final_reference_error_rad", fabs(reference.p - 0.55), 1.0e-12,
                     false);
    }
    return SERVO_OK;
}

/** @brief 轨迹到三环前馈的行为验收，误差与电流不只比较公式。 */
static void case_motion(Report *report)
{
    Stats baseline, feedforward;
    /* 两个对象从完全相同的状态和控制器增益开始。 */
    if (motion_run(report, false, &baseline) != SERVO_OK ||
        motion_run(report, true, &feedforward) != SERVO_OK)
    {
        check_metric(report, "motion.execution", 1.0, 0.0, false);
        return;
    }
    check_metric(report, "motion.baseline_rms_position_rad", baseline.rmsError, 0.1, false);
    check_metric(report, "motion.ff_rms_position_rad", feedforward.rmsError, 0.002, false);
    check_metric(report, "motion.ff_to_baseline_rms_ratio",
                 feedforward.rmsError / baseline.rmsError, 0.5, false);
    check_metric(report, "motion.baseline_peak_position_rad", baseline.peakError, 0.15, false);
    check_metric(report, "motion.ff_peak_position_rad", feedforward.peakError, 0.006, false);
    check_metric(report, "motion.baseline_peak_current_A", baseline.peakCurrent, 6.2, false);
    check_metric(report, "motion.ff_peak_current_A", feedforward.peakCurrent, 6.2, false);
    check_metric(report, "motion.baseline_settle_after_reference_s", baseline.settleS, 0.5, false);
    check_metric(report, "motion.ff_settle_after_reference_s", feedforward.settleS, 0.5, false);
    check_metric(report, "motion.ff_final_position_error_rad", feedforward.finalError, 0.001,
                 false);
}

/** @brief 逆变器非线性对象，覆盖电流翻转、母线骤降与饱和解除。 */
static ServoStatus inverter_run(Report *report, uint32_t flags, bool saturating, Stats *stats)
{
    MotorConfig config = motor_config();
    Motor motor = {config, {0.0, 0.0, 0.0, saturating ? 20.0 : 100.0}, true};
    Drive drive;
    DriveOutput output;
    FocAb pending = {0.0f, 0.0f};
    double squared = 0.0, lastOutsideS = 0.3, maxViolation = 0.0, pendingBusV = 24.0;
    size_t index, samples = 0u;
    memset(stats, 0, sizeof(*stats));
    drive_init(&drive, &config, 500.0, flags | DRIVE_DECOUPLE);
    for (index = 0u; index < 16000u; index++)
    {
        double timeS = (double)index * PERIOD_S;
        double busV = saturating && timeS >= 0.08 && timeS < 0.3 ? 6.0 : 24.0;
        double iqRef =
            saturating
                ? (timeS < 0.3 ? 12.0 : 0.0)
                : (timeS < 0.2 ? 0.35 : (timeS < 0.4 ? -0.35 : (timeS < 0.6 ? 0.10 : -0.10)));
        DriveInput input = {motor_phase(&motor),           busV, config.polePairs * motor.y[2],
                            config.polePairs * motor.y[3], 0.0,  iqRef};
        /* PWM 寄存器保持 duty；母线突变时旧 duty 对应电压必须同步缩放。 */
        FocAb heldGate = {(float)(pending.alpha * busV / pendingBusV),
                          (float)(pending.beta * busV / pendingBusV)};
        FocAb applied = inverter_apply(&motor, heldGate, busV, 0.025);
        if (drive_update(&drive, &input, &output) != SERVO_OK)
        {
            return SERVO_ERR_CALC;
        }
        pending = output.gateV;
        pendingBusV = busV;
        maxViolation = fmax(maxViolation, fmax(0.03 - output.dutyMin, output.dutyMax - 0.97));
        stats->peakCurrent = fmax(stats->peakCurrent, hypot(motor.y[0], motor.y[1]));
        if (output.saturated)
        {
            stats->saturatedTicks++;
        }
        if (!saturating && fmod(timeS, 0.2) > 0.06)
        {
            squared += motor.y[0] * motor.y[0] + (motor.y[1] - iqRef) * (motor.y[1] - iqRef);
            samples++;
        }
        if (saturating && timeS >= 0.3 && hypot(motor.y[0], motor.y[1]) > 0.05)
        {
            lastOutsideS = timeS;
        }
        if (index % 20u == 0u)
        {
            const char *name =
                saturating
                    ? ((flags & DRIVE_AW) != 0u ? "saturation_aw" : "saturation_no_aw")
                    : ((flags & DRIVE_DTC) != 0u ? "inverter_compensated" : "inverter_baseline");
            Trace trace = {name, timeS, 0.0, 0.0, 0.0, &motor, applied, 0.0, 0.0};
            write_trace(report, &trace, &output);
        }
        if (motor_update(&motor, applied) != SERVO_OK)
        {
            return SERVO_ERR_CALC;
        }
    }
    stats->rmsError = samples > 0u ? sqrt(squared / (double)samples) : 0.0;
    stats->settleS = lastOutsideS - 0.3 + PERIOD_S;
    stats->finalError = hypot(motor.y[0], motor.y[1]);
    stats->dutyViolation = fmax(0.0, maxViolation);
    return SERVO_OK;
}

/** @brief 检查补偿过零和最终约束残差，分别比较 DTC 与 AW 开关。 */
static void case_inverter(Report *report)
{
    Stats baseline, compensated, noAw, aw;
    MotorConfig config = motor_config();
    Drive drive;
    DriveInput input = {{0.3f, -0.1f, -0.2f}, 48.0, 0.2, 10.0, 0.0, 0.2};
    DriveOutput output;
    PidPiStep stepD, stepQ;
    FocDq current;
    double previous = compensation_value(-0.02, 0.6), largestStep = 0.0, monotoneError = 0.0;
    size_t index;
    /* 分别检验无饱和补偿、连续过零、DTC A/B 与母线降压后的 AW A/B。 */
    drive_init(&drive, &config, 500.0, DRIVE_DTC | DRIVE_AW);
    current = foc_park(foc_clarke(input.phaseA), foc_sincos((float)input.thetaRad));
    if (pid_pi_eval(&drive.piD, -current.d, (float)PERIOD_S, 100.0f, &stepD) != PID_OK ||
        pid_pi_eval(&drive.piQ, (float)(input.iqRefA - current.q), (float)PERIOD_S, 100.0f,
                    &stepQ) != PID_OK ||
        drive_update(&drive, &input, &output) != SERVO_OK)
    {
        check_metric(report, "inverter.execution", 1.0, 0.0, false);
        return;
    }
    check_metric(report, "inverter.unsaturated_constraint_residual_V", output.residualV, 1.0e-5,
                 false);
    check_metric(
        report, "inverter.compensation_only_integral_delta_V",
        fmax(fabs(drive.piD.integral - stepD.integral), fabs(drive.piQ.integral - stepQ.integral)),
        1.0e-5, false);
    for (index = 1u; index <= 400u; index++)
    {
        double next = compensation_value(-0.02 + 0.0001 * (double)index, 0.6);
        largestStep = fmax(largestStep, fabs(next - previous));
        monotoneError = fmax(monotoneError, previous - next);
        previous = next;
    }
    check_metric(report, "inverter.zero_crossing_max_step_V", largestStep, 0.0021, false);
    check_metric(report, "inverter.zero_crossing_monotonic_error_V", monotoneError, 0.0, false);
    check_metric(report, "inverter.zero_current_correction_V", fabs(compensation_value(0.0, 0.6)),
                 0.0, false);
    if (inverter_run(report, DRIVE_AW, false, &baseline) != SERVO_OK ||
        inverter_run(report, DRIVE_DTC | DRIVE_AW, false, &compensated) != SERVO_OK ||
        inverter_run(report, DRIVE_DTC, true, &noAw) != SERVO_OK ||
        inverter_run(report, DRIVE_DTC | DRIVE_AW, true, &aw) != SERVO_OK)
    {
        check_metric(report, "inverter.closed_loop_execution", 1.0, 0.0, false);
        return;
    }
    check_metric(report, "inverter.baseline_current_rmse_A", baseline.rmsError, 2.0, false);
    check_metric(report, "inverter.compensated_current_rmse_A", compensated.rmsError, 0.08, false);
    check_metric(report, "inverter.compensated_rmse_ratio",
                 compensated.rmsError / baseline.rmsError, 0.5, false);
    check_metric(report, "inverter.maximum_duty_violation",
                 fmax(aw.dutyViolation, compensated.dutyViolation), 2.0e-6, false);
    check_metric(report, "inverter.saturation_ticks", (double)aw.saturatedTicks, 1000.0, true);
    check_metric(report, "inverter.aw_recovery_s", aw.settleS, 0.12, false);
    check_metric(report, "inverter.no_aw_recovery_s", noAw.settleS, 0.5, false);
    check_metric(report, "inverter.aw_recovery_ratio", aw.settleS / noAw.settleS, 0.7, false);
    check_metric(report, "inverter.final_current_A", aw.finalError, 0.05, false);
}

/** @brief 非法输入必须失败且不改变已发布对象，非以 assert 代替处理。 */
static void case_invalid(Report *report)
{
    MotorConfig config = motor_config();
    Drive drive, before;
    DriveInput input = {{0.0f, 0.0f, 0.0f}, NAN, 0.0, 0.0, 0.0, 0.0};
    DriveOutput output = {0}, outputBefore;
    Motion start = {0};
    MotionLimits limits = {2.5, 10.0, 100.0};
    Trajectory trajectory = {0}, oldTrajectory;
    Fit singular = {0};
    Identified identified = {1.0, 1.0}, oldIdentified;
    drive_init(&drive, &config, 500.0, DRIVE_AW);
    trajectory.durationS = 1.0;
    before = drive;
    outputBefore = output;
    /* 无效输入发生在任何 PI 候选或状态提交前。 */
    check_metric(report, "invalid.nan_bus_rejected",
                 drive_update(&drive, &input, &output) != SERVO_OK, 1.0, true);
    check_metric(report, "invalid.drive_unchanged", memcmp(&drive, &before, sizeof(drive)) == 0,
                 1.0, true);
    check_metric(report, "invalid.output_unchanged",
                 memcmp(&output, &outputBefore, sizeof(output)) == 0, 1.0, true);
    oldTrajectory = trajectory;
    check_metric(report, "invalid.nan_target_rejected",
                 trajectory_plan(&start, NAN, &limits, &trajectory) != SERVO_OK, 1.0, true);
    check_metric(report, "invalid.trajectory_unchanged",
                 memcmp(&trajectory, &oldTrajectory, sizeof(trajectory)) == 0, 1.0, true);
    oldIdentified = identified;
    check_metric(report, "invalid.unexcited_fit_rejected",
                 fit_solve(&singular, PERIOD_S, &identified) != SERVO_OK, 1.0, true);
    check_metric(report, "invalid.fit_unchanged",
                 memcmp(&identified, &oldIdentified, sizeof(identified)) == 0, 1.0, true);
    check_metric(report, "invalid.zero_ident_period_rejected",
                 fit_solve(&singular, 0.0, &identified) == SERVO_ERR_INPUT, 1.0, true);
    check_metric(report, "invalid.null_drive_rejected",
                 drive_update(NULL, &input, &output) == SERVO_ERR_INPUT, 1.0, true);
    start.v = 3.0;
    check_metric(report, "invalid.excess_start_velocity_rejected",
                 trajectory_plan(&start, 1.0, &limits, &trajectory) != SERVO_OK, 1.0, true);
    input.busV = 0.0;
    check_metric(report, "invalid.zero_bus_rejected",
                 drive_update(&drive, &input, &output) != SERVO_OK, 1.0, true);
    input.busV = 24.0;
    input.phaseA.b = NAN;
    check_metric(report, "invalid.nan_phase_rejected",
                 drive_update(&drive, &input, &output) != SERVO_OK, 1.0, true);
    start = (Motion){0.0, limits.velocityRadS, limits.accelRadS2, 0.0};
    check_metric(report, "invalid.infeasible_braking_rejected",
                 trajectory_plan(&start, -1.0, &limits, &trajectory) != SERVO_OK, 1.0, true);
}

/** @brief 输出严格 JSON；有非有限指标时用 null 保存失败证据。 */
static int write_report(const Report *report)
{
    size_t index;
    /* 该域报告不是平台 Release Receipt，也不声明板上验证。 */
    if (printf("{\"evidence\":\"synthetic-host-c99\",\"passed\":%s,\"checks\":[",
               report->failed == 0u && !report->ioFailed ? "true" : "false") < 0)
    {
        return EXIT_FAILURE;
    }
    for (index = 0u; index < report->count; index++)
    {
        const Metric *metric = &report->metrics[index];
        if (printf("%s{\"name\":\"%s\",\"observed\":", index == 0u ? "" : ",", metric->name) < 0)
        {
            return EXIT_FAILURE;
        }
        if (isfinite(metric->observed))
        {
            (void)printf("%.12g", metric->observed);
        }
        else
        {
            (void)printf("null");
        }
        (void)printf(",\"threshold\":%.12g,\"comparison\":\"%s\",\"passed\":%s}", metric->threshold,
                     metric->minimum ? ">=" : "<=", metric->passed ? "true" : "false");
    }
    (void)printf("],\"failed\":%zu,\"io_failed\":%s}\n", report->failed,
                 report->ioFailed ? "true" : "false");
    return ferror(stdout) ? EXIT_FAILURE : EXIT_SUCCESS;
}

/** @brief 宿主入口；唯一参数为 CSV 输出路径，所有验收失败均返回非零。 */
int main(int argc, char **argv)
{
    Report report = {0};
    int reportStatus;
    if (argc != 2)
    {
        (void)fprintf(stderr, "usage: servo_validation <trace.csv>\n");
        return EXIT_FAILURE;
    }
    report.csv = fopen(argv[1], "w");
    if (report.csv == NULL)
    {
        (void)fprintf(stderr, "cannot open CSV\n");
        return EXIT_FAILURE;
    }
    /* 日志仅在宿主测试中运行，不进入实时原语。 */
    if (fprintf(
            report.csv,
            "scenario,time_s,p_ref_rad,p_rad,v_ref_rad_s,v_rad_s,a_ref_rad_s2,"
            "id_ref_A,id_A,iq_ref_A,iq_A,bus_V,pi_d_V,pi_q_V,ff_d_V,ff_q_V,dtc_alpha_V,dtc_beta_V,"
            "gate_request_alpha_V,gate_request_beta_V,gate_next_alpha_V,gate_next_beta_V,"
            "constraint_residual_V,"
            "effective_held_alpha_V,effective_held_beta_V,integral_d_V,integral_q_V,saturated,"
            "velocity_request_rad_s,torque_feedforward_A\n") < 0)
    {
        report.ioFailed = true;
    }
    case_invalid(&report);
    case_ident(&report);
    case_motion(&report);
    case_inverter(&report);
    if (fclose(report.csv) != 0)
    {
        report.ioFailed = true;
    }
    reportStatus = write_report(&report);
    return report.failed != 0u || report.ioFailed ? EXIT_FAILURE : reportStatus;
}
