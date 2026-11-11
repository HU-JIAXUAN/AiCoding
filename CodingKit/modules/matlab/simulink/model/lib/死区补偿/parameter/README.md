# 死区误差、补偿与桥臂开关校验：参数与信号

## 配置参数

默认工况的可执行入口为[deadtime_test_parameters.m](deadtime_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('DeadtimeTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md). SwitchingLegTest的PWM占空比、电流、周期与步长另见[switching_leg_test_parameters.m](switching_leg_test_parameters.m)。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| deadtimeCfg.DeadTime | 0.000002 | s | 假定有效死区；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.DeviceDrop | 0 | V | 聚合经验压降，默认省略；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.CurrentBlend | 0.1 | A | 补偿平滑区宽度；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.ModelEnable | 0 | 1 | 死区误差模型开关；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.CompensationEnable | 0 | 1 | 死区补偿开关；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.CompensationScale | 1 | 1 | 补偿幅值比例；[deadtime_parameters.m](deadtime_parameters.m) |
| deadtimeCfg.SwitchingStep | 1e-7 | s | 短时桥臂离散步长；[deadtime_parameters.m](deadtime_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| VoltageError.ia / ib / ic | A，流入电机为正 | double | Plant真值，连续；功能见搭建步骤 |
| Compensation.ia / ib / ic | A，采样反馈 | double | 100µs；功能见搭建步骤 |
| SwitchingLeg.command / current | 1 / A，外部施加电流 | double/逻辑兼容 | 0.1µs；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | ia | A |
| 2 | ib | A |
| 3 | ic | A |

SwitchingLegTest输入为第1列高侧命令、第2列外部相电流，0.1µs逐行读取；其他独立台架为100µs。

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| CurrentPolarity | 1 | sign(i) | 误差模型极性 |
| SoftPolarity | 1 | sat(i/CurrentBlend) | 补偿过零平滑 |
| CommonModePolarity | 1 | 三相极性均值 | 去除浮动中性点共同分量 |
| HighOnCounter / LowOnCounter | 计数，初始0 | UnitDelay | 连续有效开通等待时间 |
| Gateh / Gatel | boolean | 命令有效 AND 延迟已到 | 上下管不同时导通 |
| pole_voltage | V | 门极和二极管支路 | 与相对中性点电压区分 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| VoltageError.error_a / error_b / error_c | V，实际减理想 | double | 继承 |
| Compensation.comp_a / comp_b / comp_c | V | double | 100µs |
| SwitchingLeg.pole_voltage | V，对直流负端 | double | 0.1µs |
| SwitchingLeg.high_gate / low_gate | 1 | boolean；记录转double | 0.1µs |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### DeadtimeTest

实际Scope块：CurrentsScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | ia；记录列1 | DeadtimeTest/InputChannels 输出1 | A / double | a相输入电流 |
| 2 | ib；记录列2 | DeadtimeTest/InputChannels 输出2 | A / double | b相输入电流 |
| 3 | ic；记录列3 | DeadtimeTest/InputChannels 输出3 | A / double | c相输入电流 |

实际Scope块：ErrorsScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | error_a；记录列4 | DeadtimeTest/ErrorModel 输出1 | V / double | a相死区误差，实际减理想 |
| 2 | error_b；记录列5 | DeadtimeTest/ErrorModel 输出2 | V / double | b相死区误差，实际减理想 |
| 3 | error_c；记录列6 | DeadtimeTest/ErrorModel 输出3 | V / double | c相死区误差，实际减理想 |

实际Scope块：CompensationScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | comp_a；记录列7 | DeadtimeTest/Compensation 输出1 | V / double | a相调制前补偿 |
| 2 | comp_b；记录列8 | DeadtimeTest/Compensation 输出2 | V / double | b相调制前补偿 |
| 3 | comp_c；记录列9 | DeadtimeTest/Compensation 输出3 | V / double | c相调制前补偿 |

实际Scope块：ResidualScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | residual_a；记录列10 | DeadtimeTest/ResidualA 输出1 | V / double | a相误差与补偿之和 |
| 2 | residual_b；记录列11 | DeadtimeTest/ResidualB 输出1 | V / double | b相误差与补偿之和 |
| 3 | residual_c；记录列12 | DeadtimeTest/ResidualC 输出1 | V / double | c相误差与补偿之和 |


### SwitchingLegTest

实际Scope块：GatesScope，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | command；记录列1 | SwitchingLegTest/InputChannels 输出1 | 1 / double | 理想高侧门极命令 |
| 2 | high_gate；记录列4 | SwitchingLegTest/HighGateRecord 输出1 | 1 / double | 高侧实际门极，开通延迟后值 |
| 3 | low_gate；记录列5 | SwitchingLegTest/LowGateRecord 输出1 | 1 / double | 低侧实际门极，开通延迟后值 |

实际Scope块：PoleVoltageScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | pole_voltage；记录列3 | SwitchingLegTest/SwitchingLeg 输出1 | V / double | 桥臂极点对直流负端电压 |

实际Scope块：CurrentScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | phase_current；记录列2 | SwitchingLegTest/InputChannels 输出2 | A / double | 外部施加的桥臂电流，流入电机为正 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | currentCfg.Ts / deadtimeCfg.SwitchingStep | s | 直接使用；各多速率周期分别配置 |
| $V_{dc}$ | inverterCfg.Vdc | V | 直接使用 |

### 本模块局部量

本模块局部$E$为平均死区误差幅值V，$T_d,T_{PWM}$为死区/PWM周期s，$I_b$为电流平滑区间A；实际工程字段及Scope顺序沿用本页。桥臂时序计数不由平均电压式替代。
