/**
 * @file if_controller.h
 * @brief 带 D 轴强拉启动的独立 I-f；相电流输入，三相 duty 输出。
 * @author HU JIAXUAN
 */
#ifndef IF_CONTROLLER_H
#define IF_CONTROLLER_H

#include "pid_pi.h"

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    /** @brief 调用结果；IF_OK 时仍需检查 outputValid。 */
    typedef enum
    {
        IF_OK = 0,
        IF_ERR_NULL = -1,
        IF_ERR_CONFIG = -2,
        IF_ERR_INPUT = -3,
        IF_ERR_CALC = -4,
        IF_ERR_STATE = -5
    } IfStatus;

    /** @brief 仅保存当前启动步骤和停止/错误状态，不是设备状态机。 */
    typedef enum
    {
        IF_STATE_STOPPED = 0,
        IF_STATE_ALIGN,
        IF_STATE_HANDOFF,
        IF_STATE_RUNNING,
        IF_STATE_FAULT
    } IfState;

    /** @brief 电流 PI 物理增益。 */
    typedef struct
    {
        float kp; /**< V/A，有限且 > 0。 */
        float ki; /**< V/(A*s)，有限且 >= 0；零为纯比例。 */
    } IfPiConfig;

    /** @brief 固定周期及启动配置；不提供通用电机默认参数。 */
    typedef struct
    {
        float periodS;       /**< 固定周期，s，> 0。 */
        float currentLimitA; /**< 电流参考绝对上限，Apeak，> 0。 */
        float voltageLimitV; /**< 合成电压上限，V，> 0。 */
        float busMinV;       /**< 最低可用母线，V，> 0。 */
        float dutyMargin;    /**< duty 两端裕量，[0, 0.5)。 */
        IfPiConfig piD;      /**< D 轴 PI。 */
        IfPiConfig piQ;      /**< Q 轴 PI。 */
        float alignAngleRad; /**< 强拉软件电角度，[0, 2*pi)。 */
        float alignCurrentA; /**< 正 D 轴强拉电流，(0, currentLimitA] Apeak。 */
        float alignRampS;    /**< 对齐电流缓升时间，s，>= 0。 */
        float alignHoldS; /**< 缓升完成后保持时间，s，>= 0；两项不可同时为零。 */
        float frequencyRampS; /**< 启动频率爬升时间，s，>= 0。 */
    } IfConfig;

    /** @brief 调用方提供的同拍采样与命令；输入、输出和实例不得重叠。 */
    typedef struct
    {
        bool enable;            /**< false 立即停止软件输出；再次 true 重新强拉。 */
        bool sampleValid;       /**< 当前相电流和母线快照有效。 */
        float phaseCurrentA[3]; /**< 校正后的 a/b/c 电流，A。 */
        float busVoltageV;      /**< 本拍母线，V。 */
        float currentA;         /**< 运行 Q 轴目标，Apeak；独立于强拉电流。 */
        float frequencyHz;      /**< 有符号电频率，Hz；abs(f)*periodS < 0.5。 */
    } IfInput;

    /** @brief 本拍结果，失败/停止时除 state 外清零；无效 duty 不能代替关断。 */
    typedef struct
    {
        bool outputValid;            /**< true 才允许接入层应用本拍 duty。 */
        IfState state;               /**< 本拍实际执行的启动步骤。 */
        float duty[3];               /**< a/b/c 上桥臂 duty，无单位。 */
        float thetaRad;              /**< 本拍变换共用的软件电角度，rad。 */
        float frequencyHz;           /**< 本拍相位推进频率，Hz。 */
        float currentRefDqA[2];      /**< 本拍 d/q 电流参考，A。 */
        float currentFeedbackDqA[2]; /**< 本拍 d/q 反馈，A。 */
        float voltageDqV[2];         /**< 限幅后理想电压指令，V。 */
        bool currentLimited;         /**< 运行电流目标被限幅。 */
        bool voltageLimited;         /**< PI 或合成电压被限幅。 */
    } IfOutput;

    /** @brief 调用方静态持有，一个实例一个执行者；成员只由 IF 管理。 */
    typedef struct
    {
        IfConfig config;
        PidPi pi[2];
        float thetaRad;
        float thetaCompRad;
        uint32_t alignRampTicks;
        uint32_t alignTicks;
        uint32_t rampTicks;
        uint32_t tick;
        IfState state;
        IfStatus status;
        bool initialized;
    } IfController;

    /** @brief 输出已禁用时初始化一次；失败时对象不变，不操作硬件。 */
    IfStatus if_init(IfController *controller, const IfConfig *config);
    /** @brief 独占且输出已禁用时复位，清 PI/故障/相位，下一次使能重新强拉。 */
    IfStatus if_reset(IfController *controller);
    /** @brief 每个固定采样周期调用一次；检查返回值和 outputValid，再应用 duty。 */
    IfStatus if_update(IfController *controller, const IfInput *input, IfOutput *output);

#ifdef __cplusplus
}
#endif
#endif
