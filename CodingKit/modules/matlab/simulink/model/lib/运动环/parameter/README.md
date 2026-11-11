# 速度PI、位置P与离散速度给定：参数与信号

新增SpeedProfile的配置入口为[speed_profile_parameters.m](speed_profile_parameters.m)，测试默认值在[speed_profile_test_parameters.m](speed_profile_test_parameters.m)；输入、过程状态、输出、两组Scope及5列日志见[PROFILE_PARAMETERS.md](PROFILE_PARAMETERS.md)。原Position/Speed参数和Scope继续如下维护。

## 配置参数

默认工况的可执行入口为[motion_loop_test_parameters.m](motion_loop_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('MotionLoopTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| motionCfg.Ts | 0.001 | s | 本模块更新周期；[motion_parameters.m](motion_parameters.m) |
| motionCfg.NaturalFrequency | 20 | rad/s | 速度环整定自然频率；[motion_parameters.m](motion_parameters.m) |
| motionCfg.Damping | 0.9 | 1 | 速度环设计阻尼；[motion_parameters.m](motion_parameters.m) |
| motionCfg.Kt | 0.21 | N·m/A | id=0下相峰值电流转矩系数；[motion_parameters.m](motion_parameters.m) |
| motionCfg.Kp | 0.085238095 | A/(rad/s) | 速度PI比例增益；[motion_parameters.m](motion_parameters.m) |
| motionCfg.Ki | 0.95238095 | A/rad | 速度PI积分增益，未乘Ts；[motion_parameters.m](motion_parameters.m) |
| motionCfg.Kaw | 20 | 1/s | 回算增益，0关闭回算；[motion_parameters.m](motion_parameters.m) |
| motionCfg.PositionKp | 8 | 1/s | 位置P增益；[motion_parameters.m](motion_parameters.m) |
| motionCfg.SpeedLimit | 80 | rad/s | 对称机械限速；[motion_parameters.m](motion_parameters.m) |
| motionCfg.AccelerationLimit | 200 | rad/s² | 速度请求斜率限制；[motion_parameters.m](motion_parameters.m) |
| motionCfg.CurrentLimit | 8 | A | 速度PI的对称iq限制；[motion_parameters.m](motion_parameters.m) |

参数为自定义仿真夹具。原Speed输出为q轴电流请求A；SpeedProfile只生成速度给定rad/s，不包含PI，也不改变原Speed的输出单位。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| Position.reference / position | rad，机械展开位置 | double | 1ms；功能见搭建步骤 |
| Position.speed_feedforward | rad/s | double | 1ms；功能见搭建步骤 |
| Speed.reference / speed | rad/s，机械 | double | 1ms；功能见搭建步骤 |
| Speed.enable / reset | 1 | boolean | 1ms；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | position_ref | rad |
| 2 | position | rad |
| 3 | speed_ref | rad/s |
| 4 | speed | rad/s |
| 5 | speed_ff | rad/s |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| PositionError | rad | reference−position | 机械位置误差 |
| SpeedWithFeedforward | rad/s | 位置P+速度前馈 | 在共同限速之前相加 |
| SpeedLimit / SpeedSlew | rad/s、rad/s² | Saturation + RateLimiter | 速度与加速度边界 |
| SpeedPI.x_i | A，初始0 | 已有PID | 电流限幅回算积分状态 |
| iq | A，相峰值 | 速度PI输出 | 电流请求，与电磁转矩分开 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| Position.speed_request | rad/s | double | 1ms |
| Speed.iq / iq_unsaturated / integral | A | double | 1ms |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### MotionLoopTest

实际Scope块：PositionScope，纵轴：rad，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | position_reference；记录列1 | MotionLoopTest/InputChannels 输出1 | rad / double | 机械位置给定 |
| 2 | position_feedback；记录列2 | MotionLoopTest/InputChannels 输出2 | rad / double | 机械位置反馈 |

实际Scope块：SpeedScope，纵轴：rad/s，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | speed_reference；记录列3 | MotionLoopTest/InputChannels 输出3 | rad/s / double | 独立速度PI给定 |
| 2 | speed_feedback；记录列4 | MotionLoopTest/InputChannels 输出4 | rad/s / double | 机械速度反馈 |
| 3 | speed_feedforward；记录列5 | MotionLoopTest/InputChannels 输出5 | rad/s / double | 位置环求和点的速度前馈 |
| 4 | position_speed_request；记录列6 | MotionLoopTest/Position 输出1 | rad/s / double | 位置P加前馈、限速、限斜率后的速度 |

实际Scope块：CurrentScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | iq_request；记录列7 | MotionLoopTest/Speed 输出1 | A / double | 速度PI限幅后的iq |
| 2 | iq_unsaturated；记录列8 | MotionLoopTest/Speed 输出2 | A / double | 速度PI未限幅iq |
| 3 | integral_current；记录列9 | MotionLoopTest/Speed 输出3 | A / double | 速度PI积分贡献 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $\psi_m$ | motor.Flux | Wb | 直接使用 |
| $P$ | motor.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |

### 本模块局部量

$\vartheta_{shaft}$是展开机械轴位置，$b_{rot}$是旋转黏性阻尼N·m·s/rad；工程motor.B保持。原表$\theta_m$为交叉饱和角，$B$单位N·s/m，二者均不用于上述机械量。$\Omega_{v,des}$是本速度环二阶设计角频率，工程NaturalFrequency单位rad/s；不把它写为原表PLL固有频率$\omega_n$。
