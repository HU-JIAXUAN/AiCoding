# SVPWM 与平均逆变器：参数与信号

## 配置参数

默认工况的可执行入口为[inverter_test_parameters.m](inverter_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('InverterTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| inverterCfg.Vdc | 48 | V | 实验内恒定直流母线；[inverter_parameters.m](inverter_parameters.m) |
| inverterCfg.MinDuty | 0.02 | 1 | 对称最小duty预留；[inverter_parameters.m](inverter_parameters.m) |
| inverterCfg.PwmTs | 0.0001 | s | PWM周期；[inverter_parameters.m](inverter_parameters.m) |
| inverterCfg.LinearLimit | 26.6043 | V | Vdc/√3·(1−2·MinDuty)，运行入口重新计算；[inverter_parameters.m](inverter_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| SVPWM.alpha / beta | V，相峰值 | double | 继承；功能见搭建步骤 |
| Average.duty_a / duty_b / duty_c | 1 | double | 继承；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | alpha_command | V |
| 2 | beta_command | V |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| PhaseB / PhaseC | V | αβ线性组合 | 零和相参考 |
| PhaseMaximum / PhaseMinimum | V | MinMax, Inputs=1 | 三相极值 |
| CommonMode | V | −(max+min)/2 | 调制共同分量 |
| DutyLimitA/B/C | 1 | Saturation | 最终duty边界 |
| NeutralDuty | 1 | 三相duty均值 | 浮动中性点 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| SVPWM.duty_a / duty_b / duty_c | 1 | double | 继承 |
| SVPWM.common_mode | V | double | 继承 |
| Average.va / vb / vc | V，对浮动中性点 | double | 继承 |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### InverterTest

实际Scope块：Voltages，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | alpha_command；记录列1 | InverterTest/InputChannels 输出1 | V / double | α轴电压请求 |
| 2 | beta_command；记录列2 | InverterTest/InputChannels 输出2 | V / double | β轴电压请求 |
| 3 | va；记录列7 | InverterTest/Average 输出1 | V / double | a相对浮动中性点电压 |
| 4 | vb；记录列8 | InverterTest/Average 输出2 | V / double | b相对浮动中性点电压 |
| 5 | vc；记录列9 | InverterTest/Average 输出3 | V / double | c相对浮动中性点电压 |
| 6 | alpha_actual；记录列10 | InverterTest/Clarke 输出1 | V / double | 由平均输出重新Clarke得到的α电压 |
| 7 | beta_actual；记录列11 | InverterTest/Clarke 输出2 | V / double | 由平均输出重新Clarke得到的β电压 |
| 8 | zero；记录列12 | InverterTest/Clarke 输出3 | V / double | 三相电压平均值，理想浮动中性点应接近0 |

实际Scope块：Duty，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | duty_a；记录列3 | InverterTest/SVPWM 输出1 | 1 / double | a相占空比 |
| 2 | duty_b；记录列4 | InverterTest/SVPWM 输出2 | 1 / double | b相占空比 |
| 3 | duty_c；记录列5 | InverterTest/SVPWM 输出3 | 1 / double | c相占空比 |

实际Scope块：CommonMode，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | common_mode；记录列6 | InverterTest/SVPWM 输出4 | V / double | 调制注入的共同电压 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $V_{dc}$ | inverterCfg.Vdc | V | 直接使用 |

### 本模块局部量

duty为无量纲占空比；v_alpha/v_beta为相峰值约定的αβ电压。MinDuty与VoltageReserve是本模块局部无量纲配置；平均执行电压不等同瞬时开关电压。 cfg.PwmTs是名义PWM周期；SVPWM和Average均无状态，继承调用周期。
