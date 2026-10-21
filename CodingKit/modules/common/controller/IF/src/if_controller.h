/**
 * @file if_controller.h
 * @brief 独立 I-f 控制器：软件电角度、两轴电流闭环与三相 duty。
 * @author HU JIAXUAN
 */

#ifndef IF_CONTROLLER_H
#define IF_CONTROLLER_H

#include "pid.h"

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    /** @brief 控制器状态；全零对象尚未初始化。 */
    typedef enum
    {
        IF_STATE_UNINITIALIZED = 0, /**< 尚未成功配置。 */
        IF_STATE_STOPPED,           /**< 已配置、无有效激励。 */
        IF_STATE_RUNNING,           /**< 正常电流闭环。 */
        IF_STATE_STOPPING,          /**< 先降频率、再降电流。 */
        IF_STATE_FAULT              /**< 首次故障锁存，须显式复位。 */
    } IfState;

    /** @brief 单次调用结果；IF_OK 仍须检查 outputValid。 */
    typedef enum
    {
        IF_OK = 0,          /**< 调用成功。 */
        IF_ERR_NULL = -1,   /**< 必需指针为空。 */
        IF_ERR_CONFIG = -2, /**< 配置或关联约束非法。 */
        IF_ERR_STATE = -3,  /**< 生命周期不允许本次操作。 */
        IF_ERR_ACTION = -4, /**< 动作枚举非法。 */
        IF_ERR_SAMPLE = -5, /**< 活动周期采样无效。 */
        IF_ERR_NUMBER = -6, /**< 被消费输入包含 NaN/Inf。 */
        IF_ERR_RANGE = -7,  /**< 初相位不属于 [0, 2*pi)。 */
        IF_ERR_VBUS = -8,   /**< 母线低于配置下限。 */
        IF_ERR_CALC = -9    /**< 中间计算或最终调制检查失败。 */
    } IfStatus;

    /** @brief 本周期动作；START 在运行中等同 KEEP。 */
    typedef enum
    {
        IF_ACTION_KEEP = 0, /**< 保持运行状态，仍更新目标。 */
        IF_ACTION_START,    /**< 从停止态启动，不排队重启。 */
        IF_ACTION_STOP,     /**< 锁存受控停机。 */
        IF_ACTION_DISABLE   /**< 立即失效并清参考、积分。 */
    } IfAction;

    /** @brief 本周期限制标记，不锁存为设备故障。 */
    typedef enum
    {
        IF_FLAG_CURRENT_LIMITED = 1u << 0,   /**< 目标电流超出圆盘。 */
        IF_FLAG_FREQUENCY_LIMITED = 1u << 1, /**< 目标电频率超限。 */
        IF_FLAG_CURRENT_SLEW = 1u << 2,      /**< 电流尚未到限幅目标。 */
        IF_FLAG_FREQUENCY_SLEW = 1u << 3,    /**< 频率尚未到限幅目标。 */
        IF_FLAG_VOLTAGE_LIMITED = 1u << 4,   /**< 原始电压被矢量缩放。 */
        IF_FLAG_DUTY_ROUNDOFF = 1u << 5      /**< duty 发生容差内边界修正。 */
    } IfFlag;

    /** @brief 单轴电流 PI；积分状态及其上限使用 V。 */
    typedef struct
    {
        float kp;             /**< 比例增益，V/A，有限且 > 0。 */
        float ki;             /**< 积分增益，V/(A*s)，有限且 >= 0。 */
        float kaw;            /**< 最终输出回算增益，A/V，有限且 >= 0。 */
        float integralLimitV; /**< 积分绝对上限，V，属于 (0, voltageLimitV]。 */
    } IfPiConfig;

    /** @brief 显式物理配置；初始化复制，运行中由模块只读。 */
    typedef struct
    {
        float periodS;           /**< 固定周期，s，有限且 > 0。 */
        float currentLimitA;     /**< d/q 合成参考上限，A，有限且 > 0。 */
        float frequencyLimitHz;  /**< 电频率绝对上限，Hz，与周期乘积须 < 0.5。 */
        float currentSlewAps;    /**< 合成电流变化率，A/s，有限且 > 0。 */
        float frequencySlewHzps; /**< 电频率变化率，Hz/s，有限且 > 0。 */
        float voltageLimitV;     /**< 用户电压矢量上限，V，有限且 > 0。 */
        float busMinV;           /**< 有效母线下限，V，有限且 > 0。 */
        float dutyMargin;        /**< duty 两端裕量，属于 [0, 0.5)。 */
        IfPiConfig piD;          /**< d 轴电流调节配置。 */
        IfPiConfig piQ;          /**< q 轴电流调节配置。 */
    } IfConfig;

    /** @brief 调用方一次采样/命令快照，禁止与对象、输出重叠。 */
    typedef struct
    {
        IfAction action;        /**< 本周期动作。 */
        bool sampleValid;       /**< 当前三相电流和母线采样完整有效。 */
        float phaseCurrentA[3]; /**< 已校正 a/b/c 电流，A，正向为逆变器流向绕组。 */
        float busVoltageV;      /**< 本次调制配对母线，V。 */
        float frequencyTargetHz;   /**< 有符号电频率目标，Hz。 */
        float currentTargetDqA[2]; /**< d/q 电流目标，A，幅值不变变换下的峰值。 */
        float startAngleRad;       /**< 仅停止态 START 消费，rad，属于 [0, 2*pi)。 */
    } IfInput;

    /** @brief 当次完整结果；无效时除 state/status 外全部清零。 */
    typedef struct
    {
        IfState state;    /**< 调用结束状态。 */
        IfStatus status;  /**< 调用结果或锁存故障。 */
        bool outputValid; /**< true 才可应用本周期 duty；不等于硬件执行确认。 */
        float duty[3];    /**< a/b/c duty，无单位；无效时不能用零值代替禁用。 */
        uint32_t flags;   /**< IfFlag 的本周期位掩码。 */
        float currentRefDqA[2];      /**< 整形后 d/q 参考，A。 */
        float currentFeedbackDqA[2]; /**< 去零序后的 d/q 反馈，A。 */
        float frequencyRefHz;        /**< 本周期相位推进电频率，Hz。 */
        float thetaUsedRad;          /**< 本周期所有变换共用角度，rad。 */
        float deltaThetaRad;         /**< 周期末推进量，rad。 */
        float voltageRawDqV[2];      /**< 旧积分计算的 d/q 原始电压，V。 */
        float voltageAppliedDqV[2];  /**< 最终 duty 理想重建 d/q 电压，V。 */
        float voltageLimitV;  /**< 本周期母线与用户共同决定的电压上限，V。 */
        float integralDqV[2]; /**< 回算后的下一周期 d/q 积分，V。 */
    } IfOutput;

    /**
     * @brief 调用方持有的完整存储，首次以 {0} 初始化；以下成员均由模块管理。
     * @note 每实例一个执行者；禁止外部改写成员、复制运行对象或共享活动 PID 候选。
     */
    typedef struct
    {
        IfConfig config; /**< 已验证配置副本。 */
        Pid pi[2];       /**< 两个独立共享 PID 实例，仅使用 PI 与积分限幅。 */
        IfState state;   /**< 当前生命周期。 */
        IfStatus fault;  /**< 首次锁存故障。 */
        float currentRefDqA[2]; /**< 跨周期电流轨迹，A。 */
        float frequencyRefHz;   /**< 跨周期电频率，Hz。 */
        float thetaRad;         /**< 有界下一周期角度，rad。 */
        float thetaCompRad;     /**< 有界加法误差补偿，rad。 */
    } IfController;

    /**
     * @brief 验证并复制配置、清运行状态，进入 STOPPED；失败时对象完全不变。
     * @param[in,out] controller 首次为全零对象；仅未初始化、停止或故障态允许配置。
     * @param[in] config 完整物理配置，不能与对象重叠。
     * @return IF_OK 或 NULL/STATE/CONFIG 错误；不自动启动。
     */
    IfStatus if_init(IfController *controller, const IfConfig *config);

    /**
     * @brief 保留配置，清故障、轨迹、积分及相位，进入 STOPPED。
     * @param[in,out] controller 已配置且处于 STOPPED/FAULT；活动状态不允许复位。
     * @return IF_OK 或 NULL/STATE 错误；不会排队启动。
     */
    IfStatus if_reset(IfController *controller);

    /**
     * @brief 按固定 periodS 执行一个完整电流闭环周期，无硬件、时钟及动态分配。
     * @param[in,out] controller 独占实例；失败计算锁存 FAULT，清参考和积分、冻结相位。
     * @param[in] input 不重叠的只读快照；只检查本状态实际消费的字段。
     * @param[out] output 每次完整覆盖；只对本次调用有效，无效时调用方执行禁用。
     * @return IF_OK 不保证输出有效；必须同时检查 outputValid。
     */
    IfStatus if_update(IfController *controller, const IfInput *input, IfOutput *output);

#ifdef __cplusplus
}
#endif

#endif /* IF_CONTROLLER_H */
