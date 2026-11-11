# 控制采样与执行时序：参数与信号

## 配置参数

默认工况的可执行入口为[timing_test_parameters.m](timing_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('TimingTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| timingCfg.Ts | 0.0001 | s | 本模块更新周期；[timing_parameters.m](timing_parameters.m) |
| timingCfg.FeedbackTicks | 1 | 拍 | 采样后的附加反馈延迟；[timing_parameters.m](timing_parameters.m) |
| timingCfg.ActuationTicks | 1 | 拍 | 执行前的控制拍延迟；[timing_parameters.m](timing_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| Feedback.truth | 调用者定义 | double标量/定长向量 | 连续或更快；功能见搭建步骤 |
| Actuation.command | 调用者定义 | double标量/定长向量 | 控制周期；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | feedback_truth | 1 |
| 2 | voltage_command | V |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| SampleAndHold | 继承单位 | ZeroOrderHold | 在n·Ts采样并保持 |
| IntegerTickDelay | 继承单位；初值0 | Delay | 精确整数拍延迟 |
| 反馈年龄 | s | FeedbackTicks·Ts及保持内时间 | MIL近似，非板测 |
| 执行duty初值 | 1，[0;0;0] | Delay初值扩展 | 全低侧零矢量，平均相电压0；起始值不在常规MinDuty预留范围内 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| Feedback.sampled / feedback | 保留输入单位 | double | 100µs |
| Actuation.held / applied | 保留输入单位 | double | 100µs |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### TimingTest

实际Scope块：FeedbackScope，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | feedback_truth；记录列1 | TimingTest/InputChannels 输出1 | 1 / double | 时序台架的原始阶跃 |
| 2 | feedback_sampled；记录列2 | TimingTest/Feedback 输出2 | 1 / double | 采样保持后的阶跃 |
| 3 | feedback_delayed；记录列3 | TimingTest/Feedback 输出1 | 1 / double | 指定拍数延迟后的反馈 |

实际Scope块：ActuationScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | voltage_command；记录列4 | TimingTest/InputChannels 输出2 | V / double | 时序台架的原始电压命令 |
| 2 | voltage_held；记录列5 | TimingTest/Actuation 输出2 | V / double | 保持后的电压 |
| 3 | voltage_applied；记录列6 | TimingTest/Actuation 输出1 | V / double | 整数拍延迟后的电压 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |

### 本模块局部量

共同反馈帧中的theta_e、omega_e对应$\theta_r,\omega_r$；机械位置用局部$\vartheta_{shaft}$表示。$\omega$在延迟频响式中为扫频角频率，非转子速度。延迟拍数Nf/Na是本模块整数配置。
