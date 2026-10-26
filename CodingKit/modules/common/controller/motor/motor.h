#ifndef MOTOR_PRIMITIVES_H
#define MOTOR_PRIMITIVES_H

/* 平台无关电机控制补充算法；SI单位，幅值不变Park，q轴超前d轴90度 */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "foc_math.h"
#include "pid_pi.h"

#ifdef __cplusplus
extern "C"
{
#endif

    typedef enum
    {
        MC_OK = 0,             /* 输出有效 */
        MC_ERR_NULL = 1,       /* 必需指针为空 */
        MC_ERR_NUMBER = 2,     /* 非有限数或计算溢出 */
        MC_ERR_RANGE = 3,      /* 参数超出定义域 */
        MC_ERR_STALE = 4,      /* 样本过期或时间倒退 */
        MC_ERR_REVISION = 5,   /* 参数或采样版本不一致 */
        MC_ERR_SAMPLE = 6,     /* 输入样本无效 */
        MC_ERR_EVIDENCE = 7,   /* 样本不足或辨识秩不足 */
        MC_ERR_CONSTRAINT = 8, /* 稳定裕度或物理约束不满足 */
        MC_ERR_DUPLICATE = 9   /* 同一延迟或补偿已被处理 */
    } McStatus;

    typedef struct
    {
        float resistanceOhm; /* 每相定子电阻，Ohm，正数 */
        float ldH;           /* d轴微分电感，H，正数；此模块使用常参数模型 */
        float lqH;           /* q轴微分电感，H，正数 */
        float fluxWb;        /* 永磁体相磁链峰值，Wb，非负 */
        uint32_t polePairs;  /* 极对数，正整数 */
        uint32_t version;    /* 参数快照版本，非零；由应用在周期边界发布 */
    } McMotor;

    typedef struct
    {
        float kp; /* V/A，匹配pid_pi_eval先积分形式 */
        float ki; /* V/(A*s)，不是已乘Ts的系数 */
        float closedPole; /* 理想未量化模型的目标闭环极点；实际量化系数另做稳定性复检 */
        float phaseMarginRad; /* 额外纯延迟模型下的预测相位裕度，rad */
        float crossoverRadS;  /* 离散开环实际交越频率，rad/s */
    } McPiDesign;

    typedef struct
    {
        float angleRad;         /* 物理锁存时刻的电角度，rad */
        float speedRadS;        /* 同坐标电角速度，rad/s，有符号 */
        double latchTimeS;      /* 物理位置锁存时刻，s；不是接收完成时刻 */
        double targetTimeS;     /* 需要角度的时刻，s */
        float maxAgeS;          /* 允许的最大年龄，s，非负 */
        float maxPredictionRad; /* 允许的最大预测位移，rad，非负且不超过pi */
        bool valid;             /* 编码器帧/CRC/状态均有效 */
        bool alreadyPredicted;  /* 同一目标时刻是否已由其他模块做过预测 */
    } McAngle;

    typedef struct
    {
        double periodS;      /* 实际等间隔采样周期，s */
        double minRankRatio; /* 归一化行列式门槛，(0,1)，如1e-5 */
        double maxSpeedRadS; /* 允许的机械转速绝对值，rad/s；需锁轴或独立校验 */
        uint32_t minSamples; /* 至少3个区间 */
        uint32_t version;    /* 本批电压/电流/配置共同版本，非零 */
    } McRlConfig;

    typedef struct
    {
        double currentStartA; /* 区间起点电流，A */
        double currentEndA;   /* 区间终点电流，A */
        double appliedVoltageV; /* 区间内ZOH实际相等效电压，V；不能用未执行命令代替 */
        double speedRadS; /* 机械速度，rad/s */
        double periodS;   /* 本区间实测周期，s */
        uint32_t version; /* 对应配置版本 */
        bool valid;       /* 电流、电压和时序均可信 */
    } McRlSample;

    typedef struct
    {
        McRlConfig config;
        double ii, iv, vv, iy, vy, yy; /* 2x2正规方程与残差所需统计量 */
        uint32_t count;                /* 已接受区间数；到UINT32_MAX即拒绝 */
    } McRl;

    typedef struct
    {
        double resistanceOhm; /* 由精确ZOH参数a,b还原的电阻，Ohm */
        double inductanceH;   /* 由精确ZOH参数a,b还原的电感，H */
        double pole;          /* a=exp(-RTs/L)，必须在(0,1) */
        double voltageGain;   /* b=(1-a)/R，A/V，必须为正 */
        double rankRatio;     /* det(X'X)/(sum(i²)sum(v²)) */
        double residualRmsA;  /* 一步预测残差，A；独立验证集仍由调用方提供 */
        uint32_t samples;     /* 已接受样本数 */
    } McRlResult;

    typedef struct
    {
        float currentA;   /* 总相电流峰值，A，非负 */
        float direction;  /* 转矩方向，只能是+1或-1 */
        uint32_t version; /* motor参数版本 */
    } McMtpa;

    typedef struct
    {
        float currentMagnitudeA; /* sqrt(id²+iq²)，A */
        float voltageMagnitudeV; /* 稳态R/L/磁链模型的sqrt(vd²+vq²)，V */
        bool currentLimited;     /* 电流是否超限 */
        bool voltageLimited;     /* 电压是否超限；不是弱磁调节器 */
    } McLimits;

    typedef struct
    {
        float busVoltageV;       /* 母线电压，V，正数 */
        float effectiveDelayS;   /* 标定后的有符号等效开关时间误差，s */
        float pwmPeriodS;        /* 实际载波周期，s */
        float transitionA;       /* 电流零点线性过渡半宽，A，正数 */
        bool alreadyCompensated; /* 功率级/其他模块已添加相同补偿时拒绝 */
    } McDeadtime;

    typedef struct
    {
        float coulombNm;      /* 库仑摩擦，N*m，非负 */
        float staticNm;       /* 静摩擦峰值，N*m，不小于coulombNm */
        float viscousNms;     /* 粘性摩擦，N*m/(rad/s)，非负 */
        float stribeckRadS;   /* Stribeck速度尺度，rad/s，正数 */
        float transitionRadS; /* 零速平滑尺度，rad/s，正数 */
    } McFriction;

    typedef struct
    {
        float inertiaKgm2; /* 电机侧总惯量，kg*m²，正数 */
        float viscousNms;  /* 电机侧粘性阻尼，N*m/(rad/s)，非负 */
        float speedRadS;   /* 电机侧参考速度，rad/s */
        float accelRadS2;  /* 电机侧参考加速度，rad/s² */
        float knownLoadNm; /* 已知重力/负载项，N*m；坐标和符号由应用统一 */
    } McMechanical;

    typedef struct
    {
        float periodS;          /* 实际更新周期，s */
        float inertiaKgm2;      /* 名义电机侧惯量，kg*m² */
        float bandwidthRadS;    /* 一阶Q滤波角频率，rad/s */
        float maxDisturbanceNm; /* 观测输出上限，N*m，正数 */
        uint32_t version;       /* 名义参数版本，非零 */
    } McDobConfig;

    typedef struct
    {
        McDobConfig config;
        float estimateNm; /* 外部阻力矩估计，正值抵抗正向驱动 */
        float previousSpeedRadS;
        float alpha; /* init预计算1-exp(-bandwidth*Ts)，Update不再求指数 */
        bool primed; /* 第一帧只建立速度基准 */
    } McDob;

    typedef struct
    {
        float b0, b1, b2, a1, a2; /* a0=1，y=b*x-a*y；双线性预畸变 */
    } McBiquad;

    typedef struct
    {
        float x1, x2, y1, y2; /* 每个轴、每个滤波器独立状态 */
    } McBiquadState;

    typedef struct
    {
        float angleRad;     /* 更新后为下一采样时刻k+1的电角度预测，rad */
        float speedRadS;    /* 本次误差积分后的电角速度omega[k+1]，rad/s */
        float periodS;      /* 固定更新周期，s */
        float kpRadS;       /* 相位误差比例增益，1/s */
        float kiRadS2;      /* 相位误差积分增益，1/s² */
        float maxSpeedRadS; /* 速度积分上限，rad/s */
        uint32_t version;   /* 参数/样本版本，非零 */
    } McPll;

    typedef struct
    {
        double startRad;      /* 展开起点，rad；仅支持静止到静止 */
        double endRad;        /* 展开终点，rad */
        double periodS;       /* 采样周期，s */
        double maxSpeedRadS;  /* 速度绝对上限，rad/s */
        double maxAccelRadS2; /* 加速度绝对上限，rad/s² */
        double maxJerkRadS3;  /* jerk绝对上限，rad/s³ */
    } McTrajRequest;

    typedef struct
    {
        double startRad, endRad, periodS; /* 已校验并固定的采样契约 */
        uint32_t samples;                 /* 总区间数；实际持续时间=samples*periodS */
    } McTrajectory;

    typedef struct
    {
        double positionRad, speedRadS, accelRadS2, jerkRadS3; /* 同一采样时刻的PVAJ */
        bool complete; /* 到达终点；超过终点时保持位置且V/A/J为零 */
    } McTrajectoryPoint;

    typedef struct
    {
        const float *input;  /* 激励信号，调用期间只读，不保留指针 */
        const float *output; /* 同时间基准的响应，不保留指针 */
        size_t count;        /* 两个数组的共同长度，8~4096 */
        double periodS;      /* 等间隔采样周期，s */
        double frequencyHz;  /* 必须落在整周期DFT频点，Hz */
        double minAmplitude; /* 最小可信激励基波峰值，单位同input，正数 */
    } McFrfInput;

    typedef struct
    {
        double real, imaginary, magnitude, phaseRad; /* H=Y/U；相位rad */
        double inputAmplitude, outputAmplitude;      /* 整周期基波峰值 */
        uint32_t cycles;                             /* 记录中的完整周期数 */
    } McFrf;

    typedef struct
    {
        FocPhase currentA;  /* 标定到同一电流正方向的三相测量，A */
        uint32_t validMask; /* bit0/1/2分别表示A/B/C真实有效；无效字段不会读取 */
        float maxZeroSumA; /* 三相实测时允许的|Ia+Ib+Ic|，A；不强行修正三相数据 */
        double sampleTimeS; /* 电流物理采样时刻，s；双相必须已在此时刻对齐 */
        double targetTimeS; /* 使用时刻，s */
        float maxAgeS;      /* 最大年龄，s，非负 */
    } McPhaseSample;

    typedef struct
    {
        float busCurrentA;    /* 正向流入逆变器的DC-link电流，A */
        uint32_t switchState; /* bit0/1/2为A/B/C上管导通；只接受1~6有源矢量 */
        double sampleTimeS;   /* 实际S/H时刻，s；不是SOC发起或DMA完成时刻 */
        float validWindowS;   /* 包含采样保持/消隐/建立约束后可用的稳定窗，s */
        bool valid;           /* ADC、过流、放大器饱和和开关状态均已校验 */
    } McBusSample;

    typedef struct
    {
        double targetTimeS;    /* 重构电流标记的目标时刻，s */
        float minWindowS;      /* 完成采样所需的最小稳定窗，s，正数 */
        float maxAgeS;         /* 两帧各自允许的最大年龄，s，非负 */
        float maxSeparationS;  /* 两个有源矢量采样之间的最大间隔，s，非负 */
        float maxPhaseSlopeAS; /* 有证据支持的各相|di/dt|上界，A/s，非负 */
        float maxErrorA;       /* 允许的保守重构误差上界，A，非负 */
        bool slopeBoundValid; /* 斜率界已经由模型或测量支持；默认false不推定电流恒定 */
    } McShuntLimits;

    typedef struct
    {
        FocPhase currentA; /* Ia+Ib+Ic=0下的两有源矢量重构值，A */
        float errorBoundA; /* maxPhaseSlopeAS*(age1+age2)保守上界，A；不是实测误差 */
    } McReconstructed;

    /* 无特别说明时：成功才写output；失败保持输出与实例不变；所有指针必需 */
    McStatus mc_dq_ff(const McMotor *motor, FocDq currentA, float speedRadS, FocDq *voltageV);
    /* bandwidthHz是期望指数极点的连续等效频率；不是实测闭环带宽 */
    McStatus mc_pi_design(float resistanceOhm, float inductanceH, float periodS, float bandwidthHz,
                          float extraDelayS, McPiDesign *design);
    McStatus mc_pi_cfg(PidPi *pi, float kp, float ki, float error, float limit);
    McStatus mc_align_angle(const McAngle *input, float *angleRad);
    McStatus mc_rl_init(McRl *estimator, const McRlConfig *config);
    McStatus mc_rl_add(McRl *estimator, const McRlSample *sample);
    McStatus mc_rl_fit(const McRl *estimator, McRlResult *result);
    McStatus mc_mtpa(const McMotor *motor, const McMtpa *request, FocDq *currentA);
    McStatus mc_torque(const McMotor *motor, FocDq currentA, float *torqueNm);
    McStatus mc_check_limits(const McMotor *motor, FocDq currentA, float speedRadS,
                             float currentLimitA, float voltageLimitV, McLimits *result);
    McStatus mc_deadtime(const McDeadtime *config, FocPhase currentA, FocPhase *voltageV);
    McStatus mc_friction(const McFriction *config, float speedRadS, float *torqueNm);
    McStatus mc_mech_ff(const McMechanical *input, float *torqueNm);
    McStatus mc_dob_init(McDob *observer, const McDobConfig *config);
    /* appliedTorqueNm对应前后两速度样本之间的已执行平均转矩
     * valid=false时仅清除导数基准，输出不变；下一有效样本只重新建立基准，不跨丢帧求导 */
    McStatus mc_dob_update(McDob *observer, float appliedTorqueNm, float speedRadS, bool valid,
                           uint32_t version, float *disturbanceNm);
    McStatus mc_notch(float frequencyHz, float zeroDamping, float poleDamping, float periodS,
                      McBiquad *coefficients);
    McStatus mc_filter(McBiquadState *state, const McBiquad *coefficients, float input,
                       float *output);
    McStatus mc_pll_init(McPll *pll, float periodS, float bandwidthRadS, float damping,
                         float maxSpeedRadS, uint32_t version);
    McStatus mc_pll_update(McPll *pll, float measuredAngleRad, bool valid, uint32_t version);
    McStatus mc_dual_error(float motorAngleRad, float loadAngleRad, float ratio, float maxErrorRad,
                           float *loadErrorRad);
    McStatus mc_schedule(uint32_t cycle, uint32_t divisor, uint32_t phase, bool *due);
    /* 系数数组为[cos1,sin1,...]，最多16阶；angle是机械角，输出单位同系数 */
    McStatus mc_ripple(float angleRad, const float *coefficients, size_t count, float *output);
    /* 静止到静止五次多项式；规划离线执行，采样为固定阶数多项式 */
    McStatus mc_traj_plan(const McTrajRequest *request, McTrajectory *trajectory);
    McStatus mc_traj_sample(const McTrajectory *trajectory, uint32_t index,
                            McTrajectoryPoint *point);
    /* 离线相干单频DFT，拒绝非整周期；单记录不能生成相干性或闭环无偏声明 */
    McStatus mc_frf(const McFrfInput *input, McFrf *result);
    /* 2/3相电流测量；3相独立测量检验零和，2相按零和重构缺失相 */
    McStatus mc_phase_current(const McPhaseSample *sample, FocPhase *currentA);
    /* 单电阻：iDC=sA*Ia+sB*Ib+sC*Ic，显式矢量固定2x2消元，无sector猜测 */
    McStatus mc_bus_current(const McBusSample *first, const McBusSample *second,
                            const McShuntLimits *limits, McReconstructed *result);

#ifdef __cplusplus
}
#endif
#endif
