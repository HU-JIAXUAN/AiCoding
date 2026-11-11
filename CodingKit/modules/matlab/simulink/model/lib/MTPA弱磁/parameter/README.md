# 配置、输入输出、过程量和 Scope

## 配置参数

默认工况的可执行入口为[reference_test_parameters.m](reference_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_mtpa_fw_model('CurrentReferenceTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

所有值为double；使能字段只能0/1。本模块参数定义在[mtpa_fw_parameters.m](mtpa_fw_parameters.m)。电机参数或边界改变后调用[refresh_mtpa_tables.m](refresh_mtpa_tables.m)，单次实验入口会自动调用。

| 名称 | 默认值 | 单位 | 含义与定义 |
|---|---|---|---|
| refCfg.MtpaEnable | 1 | 1 | 0时候选id=0，1启用MTPA；[定义](mtpa_fw_parameters.m) |
| refCfg.FwEnable | 1 | 1 | 0时清弱磁状态，但保留MTPA和约束分配；[定义](mtpa_fw_parameters.m) |
| refCfg.CurrentMax | 8 | A | 参考dq向量峰值上限；[定义](mtpa_fw_parameters.m) |
| refCfg.IdMin | −7 | A | 最负id声明边界，须在[−CurrentMax,0]；[定义](mtpa_fw_parameters.m) |
| refCfg.VoltageReserve | 0.95 | 1 | 相对已有逆变器线性半径的预留；[定义](mtpa_fw_parameters.m) |
| refCfg.MinDuty | 0.02，随inverterCfg | 1 | 由已有逆变器配置同步，不能只改本地派生值；[定义](mtpa_fw_parameters.m) |
| refCfg.FwVoltageMargin | 0.2 | V | 弱磁调节目标比Allocator约束再低的电压；[定义](mtpa_fw_parameters.m) |
| refCfg.FwTs | 0.001 | s | 弱磁滤波/状态更新周期；[定义](mtpa_fw_parameters.m) |
| refCfg.FilterTau | 0.003 | s | 后向欧拉电压一阶低通时间常数；[定义](mtpa_fw_parameters.m) |
| refCfg.FwKi | 50 | A/(V·s) | 弱磁积分增益；[定义](mtpa_fw_parameters.m) |
| refCfg.IdSlew | 200 | A/s | 弱磁状态逐拍最大变化速度；[定义](mtpa_fw_parameters.m) |
| refCfg.TablePoints | 257 | 点 | 0至CurrentMax的MTPA表点数；[定义](mtpa_fw_parameters.m) |
| refCfg.SpeedTs | 0.001 | s | 新转矩PI周期，必须等于motionCfg.Ts；[定义](mtpa_fw_parameters.m) |
| refCfg.SpeedKp | 0.0179 | N·m·s/rad | 机械速度误差比例增益；[定义](mtpa_fw_parameters.m) |
| refCfg.SpeedKi | 0.2 | N·m/rad | 机械速度误差积分增益；[定义](mtpa_fw_parameters.m) |
| refCfg.SpeedKaw | 20 | 1/s | 分配转矩残差回算增益；[定义](mtpa_fw_parameters.m) |

派生值也存入refCfg，仅由refresh函数重建：

| 名称 | 默认值/维度 | 单位 | 含义与定义 |
|---|---|---|---|
| IdTable | 1×257 | A | MTPA d候选；[生成](refresh_mtpa_tables.m) |
| TorqueGrid | 1×257，严格递增 | N·m | MTPA正转矩断点；[生成](refresh_mtpa_tables.m) |
| MaxTorque | 约1.68175 | N·m | 电流/负id边界下MTPA表的末端转矩，不考虑电压；[生成](refresh_mtpa_tables.m) |
| Kt | 0.21 | N·m/A | id=0时转矩系数；[生成](refresh_mtpa_tables.m) |
| VoltageFactor | 约0.526543 | 1 | 0.95×(1−2×0.02)/sqrt(3)；[生成](refresh_mtpa_tables.m) |
| FilterAlpha | 0.75 | 1 | tau/(tau+FwTs)；[生成](refresh_mtpa_tables.m) |

电机与已有配置保持原模块归属：

| 名称 | 默认值 | 单位 | 含义与定义 |
|---|---|---|---|
| pmsmCfg.Rs / Ld / Lq / Flux / PolePairs | 0.5 / 0.001 / 0.0012 / 0.035 / 4 | Ω / H / H / Wb / 极对 | [pmsm_parameters.m](../../永磁同步电机/parameter/pmsm_parameters.m)；本模块要求Rs>0、Lq≥Ld>0、Flux>0 |
| pmsmCfg.J / B | 0.0005 / 0.0001 | kg·m² / N·m·s/rad | 同上，数学对象参数 |
| currentCfg.Ts | 0.0001 | s | [current_parameters.m](../../电流环/parameter/current_parameters.m)，分配运算/电流拍 |
| inverterCfg.Vdc / MinDuty | 48 / 0.02 | V / 1 | [inverter_parameters.m](../../逆变器/parameter/inverter_parameters.m) |
| timingCfg | 原采样与执行延迟 | s/拍 | [timing_parameters.m](../../采样执行时序/parameter/timing_parameters.m) |
| experimentCfg.Step | 0.000005 | s | [experiment_parameters.m](../../../app_models/Sensor/experiment/parameter/experiment_parameters.m)，整机ode4步长 |
| experimentCfg.Mode / SpeedReference / SpeedInitial | 1 / 218 / 0 | 1 / rad/s / rad/s | 新整机默认覆盖在[reference_case_parameters.m](reference_case_parameters.m) |
| experimentCfg.CommandTime / LoadTorque / LoadTime | 0.05 / 0.05 / 0 | s / N·m / s | 同上；默认整机时长2s |
| motionCfg.SpeedLimit / AccelerationLimit | 260 / 200 | rad/s / rad/s² | 新整机速度限幅覆盖260；其余复用[motion_parameters.m](../../运动环/parameter/motion_parameters.m) |
| feedforwardCfg.Enable | 1 | 1 | 新整机启用dq前馈；[feedforward_parameters.m](../../电压前馈/parameter/feedforward_parameters.m) |
| deadtimeCfg | 沿用原默认 | SI | [deadtime_parameters.m](../../死区补偿/parameter/deadtime_parameters.m)；本批未另改死区开关 |
| refTestCfg.Duration / TorqueReference / TorqueInitial | 0.25 / 0.2 / 0 | s / N·m / N·m | [reference_test_parameters.m](reference_test_parameters.m)；整机mode0时用TorqueReference/Initial |
| refTestCfg.ElectricalSpeed / Vdc / VoltageDemand | 800 / 48 / 28 | rad/s / V / V | 组件默认输入；VoltageDemand在0.02s加阶跃，非整机反馈 |

## 输入信号

Allocator端口1–6按下表顺序。六列testStim也用此顺序，采样间隔100µs。整机输入来自转矩PI/命令、反馈和电压上一拍快照。

| 名称 | 单位 | 类型或初值 | 来源/用途 |
|---|---|---|---|
| torque_request | N·m | double | 组件第1列；整机TorqueStage，速度PI输出或mode0直接命令 |
| omega_e | rad/s | double，带符号 | 组件第2列；整机FeedbackStage电角速度，等于机械速度×极对数 |
| bus_voltage | V | double，非负 | 组件第3列；整机母线配置，此版为常量 |
| voltage_demand_prev | V | double，整机延迟初值0 | 组件第4列外施；整机PI+FF模长经100µs Unit Delay |
| enable | 1 | double/逻辑兼容，0或1 | 组件第5列；整机控制状态 |
| reset | 1 | double/逻辑兼容，0或1 | 组件第6列；1优先复位 |

TorquePI额外输入为speed_error(rad/s)、torque_residual(N·m)、enable/reset；误差来源是限速/限斜率后的机械速度请求减反馈。默认state=0。

## 过程变量

| 名称 | 单位 | 类型或状态初值 | 所在块与计算/用途 |
|---|---|---|---|
| Tlimited | N·m | double，无状态 | MTPA：sign(T)×min(abs(T),MaxTorque) |
| id_candidate | A | double | Allocator：min(id_mtpa,id_fw)，夹到[IdMin,0] |
| Utarget | V | double | FieldWeakening/VoltageTargetMargin→NonnegativeTarget：max(0,Uavail−0.2V) |
| VoltageMemory | V | Unit Delay，IC=0 | 上一弱磁拍滤波值，1ms；与新需求加权 |
| FieldMemory | A | Unit Delay，IC=0 | 当前弱磁积分状态x[k]；先输出后更新下一状态 |
| IntegralIncrement / IncrementBound | A/拍 | double | FwKi×FwTs×eU，再夹到±IdSlew×FwTs=±0.2A |
| RequestedIq | A | double | Trequest/[1.5p(Flux+(Ld−Lq)id_candidate)] |
| CurrentOnlyLower / Upper | A | double | 只按电流圆和转矩方向夹RequestedIq，供Umodel计算 |
| a / b / c / D | 组合SI系数 | double | CurrentLimits电压二次不等式；公式见[DESIGN](../build_process/DESIGN.md) |
| current_lo / hi，voltage_lo / hi | A | double | 电流圆/方向边界与电压二次式根区间，求交后分配iq |
| previousDemand | V | Unit Delay，IC=0 | 整机上一完整电流拍PI+FF模长，100µs |
| speed_pi_integral | N·m | Unit Delay，IC=0 | TorquePI：xi_next=xi+Ts(Ki·eω+Kaw·Tresidual)，1ms |
| Active / ResetFilter / ResetFieldState | 1 / V / A | boolean/double | 禁能、复位或关闭弱磁清状态；不把状态清零等同门极关断 |

## 输出信号

Allocator的19个输出端口按下表顺序；前三个可直接给电流环及上层。标志在模型中为boolean，接Scope/trace前转double 0/1。数值为double。无状态输出100µs更新；id_fw、filtered_voltage、voltage_error由1ms状态保持。

| 序号 | 名称 | 单位 | 类型/来源及用途 |
|---|---|---|---|
| 1 | id_reference | A | double；最终分配d电流参考 |
| 2 | iq_reference | A | double；最终分配q电流参考 |
| 3 | allocated_torque | N*m | double；最终参考电流对应的转矩 |
| 4 | id_mtpa | A | double；MTPA d候选 |
| 5 | iq_mtpa | A | double；MTPA q候选，未做电压投影 |
| 6 | id_fw | A | double；弱磁积分当前状态/候选 |
| 7 | filtered_voltage | V | double；有效电压需求经1ms滤波后的值 |
| 8 | voltage_available | V | double；Allocator的电压约束半径 |
| 9 | predicted_voltage | V | double；最终参考的稳态电压模长 |
| 10 | current_margin | A | double；CurrentMax减参考向量模长 |
| 11 | voltage_margin | V | double；可用电压减预测电压；不可行时可为负 |
| 12 | torque_residual | N*m | double；分配转矩减请求转矩；速度PI回算输入 |
| 13 | current_limited | 1 | boolean；原请求iq超出当前id下的电流圆 |
| 14 | voltage_limited | 1 | boolean；电流圆夹限后的需求超压，或无可行交集 |
| 15 | feasible | 1 | boolean；当前id的电压/电流/方向区间有交集且控制激活 |
| 16 | fw_active | 1 | boolean；弱磁候选比MTPA更负且控制激活；不是可行标志 |
| 17 | voltage_error | V | double；max(0,Uavail−FwVoltageMargin)减滤波电压；负值使id更负 |
| 18 | model_voltage_demand | V | double；请求转矩经电流圆限制后所需电压，未做电压投影 |
| 19 | effective_voltage_demand | V | double；max(上一拍实际需求,模型需求) |

TorquePI另输出Trequest(N·m)和xi(N·m)。feasible=false不承诺Upred≤Uavail；allocated_torque只表示所分配参考的转矩。current_limited、voltage_limited与fw_active可以同时或分别置位，不能用任何一个替代feasible。

## Scope 通道

通道按实际Scope输入展开的顺序编号，来源包含实际块路径/端口；trace列是保存数据中的列号。dq向量后缀1=d、2=q；abc后缀1=a、2=b、3=c。Scope均打开legend并自动缩放；颜色不作为通道身份。所有trace记录为double，逻辑标志0/1。数据来源索引保存于[model_channels.json](../build_process/model_channels.json)。

### CurrentReferenceTest：25列trace，5组Scope

**Currents**（blk_11）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id_reference | `CurrentReferenceTest/CurrentAllocator`，blk_3.y1；trace列7 | A / double | 最终分配d电流参考 |
| 2 | iq_reference | `CurrentReferenceTest/CurrentAllocator`，blk_3.y2；trace列8 | A / double | 最终分配q电流参考 |
| 3 | id_mtpa | `CurrentReferenceTest/CurrentAllocator`，blk_3.y4；trace列10 | A / double | MTPA d候选 |
| 4 | iq_mtpa | `CurrentReferenceTest/CurrentAllocator`，blk_3.y5；trace列11 | A / double | MTPA q候选，未做电压投影 |
| 5 | id_fw | `CurrentReferenceTest/CurrentAllocator`，blk_3.y6；trace列12 | A / double | 弱磁积分当前状态/候选 |
| 6 | current_margin | `CurrentReferenceTest/CurrentAllocator`，blk_3.y10；trace列16 | A / double | CurrentMax减参考向量模长 |

**Torques**（blk_13）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | torque_request | `CurrentReferenceTest/Inputs`，blk_2.y1；trace列1 | N*m / double | 分配前转矩请求；正负对应iq方向 |
| 2 | allocated_torque | `CurrentReferenceTest/CurrentAllocator`，blk_3.y3；trace列9 | N*m / double | 最终参考电流对应的转矩 |
| 3 | torque_residual | `CurrentReferenceTest/CurrentAllocator`，blk_3.y12；trace列18 | N*m / double | 分配转矩减请求转矩；速度PI回算输入 |

**Voltages**（blk_15）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | bus_voltage | `CurrentReferenceTest/Inputs`，blk_2.y3；trace列3 | V / double | 直流母线；决定可用电压 |
| 2 | voltage_demand_prev | `CurrentReferenceTest/Inputs`，blk_2.y4；trace列4 | V / double | 上一完整拍限幅前PI+FF模长 |
| 3 | filtered_voltage | `CurrentReferenceTest/CurrentAllocator`，blk_3.y7；trace列13 | V / double | 有效电压需求经1ms滤波后的值 |
| 4 | voltage_available | `CurrentReferenceTest/CurrentAllocator`，blk_3.y8；trace列14 | V / double | Allocator的电压约束半径 |
| 5 | predicted_voltage | `CurrentReferenceTest/CurrentAllocator`，blk_3.y9；trace列15 | V / double | 最终参考的稳态电压模长 |
| 6 | voltage_margin | `CurrentReferenceTest/CurrentAllocator`，blk_3.y11；trace列17 | V / double | 可用电压减预测电压；不可行时可为负 |
| 7 | voltage_error | `CurrentReferenceTest/CurrentAllocator`，blk_3.y17；trace列23 | V / double | max(0,Uavail−FwVoltageMargin)减滤波电压；负值使id更负 |
| 8 | model_voltage_demand | `CurrentReferenceTest/CurrentAllocator`，blk_3.y18；trace列24 | V / double | 请求转矩经电流圆限制后所需电压，未做电压投影 |
| 9 | effective_voltage_demand | `CurrentReferenceTest/CurrentAllocator`，blk_3.y19；trace列25 | V / double | max(上一拍实际需求,模型需求) |

**ElectricalSpeed**（blk_17）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | omega_e | `CurrentReferenceTest/Inputs`，blk_2.y2；trace列2 | rad/s / double | 带符号电角速度，非机械速度 |

**State**（blk_19）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | enable | `CurrentReferenceTest/Inputs`，blk_2.y5；trace列5 | 1 / double | 控制器使能；0清状态和参考，不等同硬件停机 |
| 2 | reset | `CurrentReferenceTest/Inputs`，blk_2.y6；trace列6 | 1 / double | 1优先清状态和参考 |
| 3 | current_limited | `CurrentReferenceTest/Recordcurrent_limited`，blk_4.y1；trace列19 | 1 / double | 原请求iq超出当前id下的电流圆 |
| 4 | voltage_limited | `CurrentReferenceTest/Recordvoltage_limited`，blk_5.y1；trace列20 | 1 / double | 电流圆夹限后的需求超压，或无可行交集 |
| 5 | feasible | `CurrentReferenceTest/Recordfeasible`，blk_6.y1；trace列21 | 1 / double | 当前id的电压/电流/方向区间有交集且控制激活 |
| 6 | fw_active | `CurrentReferenceTest/Recordfw_active`，blk_7.y1；trace列22 | 1 / double | 弱磁候选比MTPA更负且控制激活；不是可行标志 |

### MTPAFWMotor：74列trace，15组Scope

**Currents**（blk_184）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id_reference | `MTPAFWMotor/CurrentAllocator`，blk_224.y1；trace列1 | A / double | 最终分配d电流参考 |
| 2 | iq_reference | `MTPAFWMotor/CurrentAllocator`，blk_224.y2；trace列2 | A / double | 最终分配q电流参考 |
| 3 | id_truth | `MTPAFWMotor/Electrical`，blk_153.y1；trace列3 | A / double | Plant d电流真值，仅供分析 |
| 4 | iq_truth | `MTPAFWMotor/Electrical`，blk_153.y2；trace列4 | A / double | Plant q电流真值，仅供分析 |
| 5 | id_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y1；trace列5 | A / double | 采样/延迟/坐标变换后的d反馈 |
| 6 | iq_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y2；trace列6 | A / double | 采样/延迟/坐标变换后的q反馈 |

**Voltages**（blk_186）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | voltage_request_dq_1 | `MTPAFWMotor/CurrentStage`，blk_13.y1；trace列7 | V / double | 限幅前PI+FF向量，d/q，向量分量1 |
| 2 | voltage_request_dq_2 | `MTPAFWMotor/CurrentStage`，blk_13.y1；trace列8 | V / double | 限幅前PI+FF向量，d/q，向量分量2 |
| 3 | voltage_pi_dq_1 | `MTPAFWMotor/CurrentStage`，blk_13.y2；trace列9 | V / double | 双轴PI分量，向量分量1 |
| 4 | voltage_pi_dq_2 | `MTPAFWMotor/CurrentStage`，blk_13.y2；trace列10 | V / double | 双轴PI分量，向量分量2 |
| 5 | voltage_ff_dq_1 | `MTPAFWMotor/CurrentStage`，blk_13.y3；trace列11 | V / double | dq解耦与反电势前馈分量，向量分量1 |
| 6 | voltage_ff_dq_2 | `MTPAFWMotor/CurrentStage`，blk_13.y3；trace列12 | V / double | dq解耦与反电势前馈分量，向量分量2 |
| 7 | integral_dq_1 | `MTPAFWMotor/CurrentStage`，blk_13.y4；trace列13 | V / double | 电流PI积分状态，向量分量1 |
| 8 | integral_dq_2 | `MTPAFWMotor/CurrentStage`，blk_13.y4；trace列14 | V / double | 电流PI积分状态，向量分量2 |
| 9 | voltage_residual_dq_1 | `MTPAFWMotor/VoltageStage`，blk_29.y6；trace列15 | V / double | 同评价点最终电压减请求电压的回算残差，向量分量1 |
| 10 | voltage_residual_dq_2 | `MTPAFWMotor/VoltageStage`，blk_29.y6；trace列16 | V / double | 同评价点最终电压减请求电压的回算残差，向量分量2 |
| 11 | vd_plant | `MTPAFWMotor/VoltageStage`，blk_29.y1；trace列17 | V / double | 实际输入Plant的d电压 |
| 12 | vq_plant | `MTPAFWMotor/VoltageStage`，blk_29.y2；trace列18 | V / double | 实际输入Plant的q电压 |
| 13 | feasible_command_dq_1 | `MTPAFWMotor/VoltageStage`，blk_29.y7；trace列19 | V / double | 最终调制命令重建的dq电压，向量分量1 |
| 14 | feasible_command_dq_2 | `MTPAFWMotor/VoltageStage`，blk_29.y7；trace列20 | V / double | 最终调制命令重建的dq电压，向量分量2 |

**Duty**（blk_188）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | duty_command_abc_1 | `MTPAFWMotor/VoltageStage`，blk_29.y3；trace列21 | 1 / double | 当前命令三相占空比，向量分量1 |
| 2 | duty_command_abc_2 | `MTPAFWMotor/VoltageStage`，blk_29.y3；trace列22 | 1 / double | 当前命令三相占空比，向量分量2 |
| 3 | duty_command_abc_3 | `MTPAFWMotor/VoltageStage`，blk_29.y3；trace列23 | 1 / double | 当前命令三相占空比，向量分量3 |
| 4 | duty_applied_abc_1 | `MTPAFWMotor/VoltageStage`，blk_29.y4；trace列24 | 1 / double | 含执行延迟的三相占空比，向量分量1 |
| 5 | duty_applied_abc_2 | `MTPAFWMotor/VoltageStage`，blk_29.y4；trace列25 | 1 / double | 含执行延迟的三相占空比，向量分量2 |
| 6 | duty_applied_abc_3 | `MTPAFWMotor/VoltageStage`，blk_29.y4；trace列26 | 1 / double | 含执行延迟的三相占空比，向量分量3 |
| 7 | voltage_limit_scale | `MTPAFWMotor/VoltageStage`，blk_29.y5；trace列27 | 1 / double | 原电压向量限制比例 |

**Torques**（blk_190）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | electromagnetic_torque | `MTPAFWMotor/Electrical`，blk_153.y3；trace列28 | N*m / double | Plant电磁转矩，区别于参考分配转矩 |
| 2 | load_torque | `MTPAFWMotor/LoadTorque`，blk_176.y1；trace列29 | N*m / double | 外部机械负载转矩 |

**Speed**（blk_192）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | speed_request | `MTPAFWMotor/TorqueStage`，blk_209.y2；trace列30 | rad/s / double | 限速/限斜率后的机械速度请求 |
| 2 | speed_truth | `MTPAFWMotor/MechanicalSpeed`，blk_168.y1；trace列31 | rad/s / double | Plant机械速度，仅供分析 |
| 3 | speed_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y4；trace列32 | rad/s / double | 机械速度反馈 |
| 4 | electrical_speed_truth | `MTPAFWMotor/ElectricalSpeed`，blk_170.y1；trace列38 | rad/s / double | Plant电角速度 |
| 5 | electrical_speed_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y6；trace列39 | rad/s / double | 反馈电角速度；Allocator使用这个量 |

**Position**（blk_194）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | position_reference | `MTPAFWMotor/PositionCommand`，blk_172.y1；trace列33 | rad / double | 机械位置给定 |
| 2 | position_truth | `MTPAFWMotor/MechanicalPosition`，blk_169.y1；trace列34 | rad / double | Plant机械位置 |
| 3 | position_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y5；trace列35 | rad / double | 机械位置反馈 |

**ElectricalAngle**（blk_196）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | electrical_angle_truth | `MTPAFWMotor/ElectricalAngle`，blk_171.y1；trace列36 | rad / double | Plant电角度 |
| 2 | electrical_angle_feedback | `MTPAFWMotor/FeedbackStage`，blk_64.y3；trace列37 | rad / double | 反馈电角度 |

**PhaseCurrents**（blk_198）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | ia_truth | `MTPAFWMotor/CurrentInverseClarke`，blk_156.y1；trace列40 | A / double | a相电流真值 |
| 2 | ib_truth | `MTPAFWMotor/CurrentInverseClarke`，blk_156.y2；trace列41 | A / double | b相电流真值 |
| 3 | ic_truth | `MTPAFWMotor/CurrentInverseClarke`，blk_156.y3；trace列42 | A / double | c相电流真值 |

**InverterVoltages**（blk_200）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | inverter_phase_voltage_abc_1 | `MTPAFWMotor/VoltageStage`，blk_29.y8；trace列43 | V / double | 逆变器三相端电压，向量分量1 |
| 2 | inverter_phase_voltage_abc_2 | `MTPAFWMotor/VoltageStage`，blk_29.y8；trace列44 | V / double | 逆变器三相端电压，向量分量2 |
| 3 | inverter_phase_voltage_abc_3 | `MTPAFWMotor/VoltageStage`，blk_29.y8；trace列45 | V / double | 逆变器三相端电压，向量分量3 |
| 4 | deadtime_error_abc_1 | `MTPAFWMotor/VoltageStage`，blk_29.y9；trace列46 | V / double | 死区引入的三相误差，向量分量1 |
| 5 | deadtime_error_abc_2 | `MTPAFWMotor/VoltageStage`，blk_29.y9；trace列47 | V / double | 死区引入的三相误差，向量分量2 |
| 6 | deadtime_error_abc_3 | `MTPAFWMotor/VoltageStage`，blk_29.y9；trace列48 | V / double | 死区引入的三相误差，向量分量3 |

**CurrentError**（blk_202）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | current_error_dq_1 | `MTPAFWMotor/CurrentStage`，blk_13.y5；trace列49 | A / double | 参考减采样反馈的dq电流误差，向量分量1 |
| 2 | current_error_dq_2 | `MTPAFWMotor/CurrentStage`，blk_13.y5；trace列50 | A / double | 参考减采样反馈的dq电流误差，向量分量2 |

**ControlState**（blk_204）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | enable | `MTPAFWMotor/EnableRecord`，blk_179.y1；trace列51 | 1 / double | 控制器使能；0清状态和参考，不等同硬件停机 |
| 2 | reset | `MTPAFWMotor/ResetRecord`，blk_180.y1；trace列52 | 1 / double | 1优先清状态和参考 |

**AllocationTorque**（blk_248）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | torque_request | `MTPAFWMotor/TorqueStage`，blk_209.y1；trace列53 | N*m / double | 分配前转矩请求；正负对应iq方向 |
| 2 | allocated_torque | `MTPAFWMotor/CurrentAllocator`，blk_224.y3；trace列54 | N*m / double | 最终参考电流对应的转矩 |
| 3 | torque_residual | `MTPAFWMotor/CurrentAllocator`，blk_224.y12；trace列55 | N*m / double | 分配转矩减请求转矩；速度PI回算输入 |
| 4 | speed_pi_torque | `MTPAFWMotor/TorqueStage`，blk_209.y3；trace列70 | N*m / double | 新速度PI输出，单位N·m |
| 5 | speed_pi_integral | `MTPAFWMotor/TorqueStage`，blk_209.y4；trace列71 | N*m / double | 新速度PI积分状态，单位N·m |

**WeakeningCurrents**（blk_250）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id_reference | `MTPAFWMotor/CurrentAllocator`，blk_224.y1；trace列1 | A / double | 最终分配d电流参考 |
| 2 | iq_reference | `MTPAFWMotor/CurrentAllocator`，blk_224.y2；trace列2 | A / double | 最终分配q电流参考 |
| 3 | id_mtpa | `MTPAFWMotor/CurrentAllocator`，blk_224.y4；trace列56 | A / double | MTPA d候选 |
| 4 | iq_mtpa | `MTPAFWMotor/CurrentAllocator`，blk_224.y5；trace列57 | A / double | MTPA q候选，未做电压投影 |
| 5 | id_fw | `MTPAFWMotor/CurrentAllocator`，blk_224.y6；trace列58 | A / double | 弱磁积分当前状态/候选 |
| 6 | current_margin | `MTPAFWMotor/CurrentAllocator`，blk_224.y10；trace列62 | A / double | CurrentMax减参考向量模长 |

**WeakeningVoltages**（blk_252）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | filtered_voltage | `MTPAFWMotor/CurrentAllocator`，blk_224.y7；trace列59 | V / double | 有效电压需求经1ms滤波后的值 |
| 2 | voltage_available | `MTPAFWMotor/CurrentAllocator`，blk_224.y8；trace列60 | V / double | Allocator的电压约束半径 |
| 3 | predicted_voltage | `MTPAFWMotor/CurrentAllocator`，blk_224.y9；trace列61 | V / double | 最终参考的稳态电压模长 |
| 4 | voltage_margin | `MTPAFWMotor/CurrentAllocator`，blk_224.y11；trace列63 | V / double | 可用电压减预测电压；不可行时可为负 |
| 5 | voltage_error | `MTPAFWMotor/CurrentAllocator`，blk_224.y17；trace列68 | V / double | max(0,Uavail−FwVoltageMargin)减滤波电压；负值使id更负 |
| 6 | voltage_demand_prev | `MTPAFWMotor/PreviousVoltageDemand`，blk_228.y1；trace列69 | V / double | 上一完整拍限幅前PI+FF模长 |
| 7 | bus_voltage | `MTPAFWMotor/AllocatorBus`，blk_225.y1；trace列72 | V / double | 直流母线；决定可用电压 |
| 8 | model_voltage_demand | `MTPAFWMotor/CurrentAllocator`，blk_224.y18；trace列73 | V / double | 请求转矩经电流圆限制后所需电压，未做电压投影 |
| 9 | effective_voltage_demand | `MTPAFWMotor/CurrentAllocator`，blk_224.y19；trace列74 | V / double | max(上一拍实际需求,模型需求) |

**AllocationState**（blk_254）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | current_limited | `MTPAFWMotor/Recordcurrent_limited`，blk_243.y1；trace列64 | 1 / double | 原请求iq超出当前id下的电流圆 |
| 2 | voltage_limited | `MTPAFWMotor/Recordvoltage_limited`，blk_244.y1；trace列65 | 1 / double | 电流圆夹限后的需求超压，或无可行交集 |
| 3 | feasible | `MTPAFWMotor/Recordfeasible`，blk_245.y1；trace列66 | 1 / double | 当前id的电压/电流/方向区间有交集且控制激活 |
| 4 | fw_active | `MTPAFWMotor/Recordfw_active`，blk_246.y1；trace列67 | 1 / double | 弱磁候选比MTPA更负且控制激活；不是可行标志 |

### 全部保存列索引

以下包括未单独送Scope的保存量；是否为Scope通道以上面的窗口连接表为准。

**CurrentReferenceTest**

| trace列 | 名称 | 单位 | 含义 |
|---|---|---|---|
| 1 | torque_request | N*m | 分配前转矩请求；正负对应iq方向 |
| 2 | omega_e | rad/s | 带符号电角速度，非机械速度 |
| 3 | bus_voltage | V | 直流母线；决定可用电压 |
| 4 | voltage_demand_prev | V | 上一完整拍限幅前PI+FF模长 |
| 5 | enable | 1 | 控制器使能；0清状态和参考，不等同硬件停机 |
| 6 | reset | 1 | 1优先清状态和参考 |
| 7 | id_reference | A | 最终分配d电流参考 |
| 8 | iq_reference | A | 最终分配q电流参考 |
| 9 | allocated_torque | N*m | 最终参考电流对应的转矩 |
| 10 | id_mtpa | A | MTPA d候选 |
| 11 | iq_mtpa | A | MTPA q候选，未做电压投影 |
| 12 | id_fw | A | 弱磁积分当前状态/候选 |
| 13 | filtered_voltage | V | 有效电压需求经1ms滤波后的值 |
| 14 | voltage_available | V | Allocator的电压约束半径 |
| 15 | predicted_voltage | V | 最终参考的稳态电压模长 |
| 16 | current_margin | A | CurrentMax减参考向量模长 |
| 17 | voltage_margin | V | 可用电压减预测电压；不可行时可为负 |
| 18 | torque_residual | N*m | 分配转矩减请求转矩；速度PI回算输入 |
| 19 | current_limited | 1 | 原请求iq超出当前id下的电流圆 |
| 20 | voltage_limited | 1 | 电流圆夹限后的需求超压，或无可行交集 |
| 21 | feasible | 1 | 当前id的电压/电流/方向区间有交集且控制激活 |
| 22 | fw_active | 1 | 弱磁候选比MTPA更负且控制激活；不是可行标志 |
| 23 | voltage_error | V | max(0,Uavail−FwVoltageMargin)减滤波电压；负值使id更负 |
| 24 | model_voltage_demand | V | 请求转矩经电流圆限制后所需电压，未做电压投影 |
| 25 | effective_voltage_demand | V | max(上一拍实际需求,模型需求) |

**MTPAFWMotor**

| trace列 | 名称 | 单位 | 含义 |
|---|---|---|---|
| 1 | id_reference | A | 最终分配d电流参考 |
| 2 | iq_reference | A | 最终分配q电流参考 |
| 3 | id_truth | A | Plant d电流真值，仅供分析 |
| 4 | iq_truth | A | Plant q电流真值，仅供分析 |
| 5 | id_feedback | A | 采样/延迟/坐标变换后的d反馈 |
| 6 | iq_feedback | A | 采样/延迟/坐标变换后的q反馈 |
| 7–8 | voltage_request_dq | V | 限幅前PI+FF向量，d/q |
| 9–10 | voltage_pi_dq | V | 双轴PI分量 |
| 11–12 | voltage_ff_dq | V | dq解耦与反电势前馈分量 |
| 13–14 | integral_dq | V | 电流PI积分状态 |
| 15–16 | voltage_residual_dq | V | 同评价点最终电压减请求电压的回算残差 |
| 17 | vd_plant | V | 实际输入Plant的d电压 |
| 18 | vq_plant | V | 实际输入Plant的q电压 |
| 19–20 | feasible_command_dq | V | 最终调制命令重建的dq电压 |
| 21–23 | duty_command_abc | 1 | 当前命令三相占空比 |
| 24–26 | duty_applied_abc | 1 | 含执行延迟的三相占空比 |
| 27 | voltage_limit_scale | 1 | 原电压向量限制比例 |
| 28 | electromagnetic_torque | N*m | Plant电磁转矩，区别于参考分配转矩 |
| 29 | load_torque | N*m | 外部机械负载转矩 |
| 30 | speed_request | rad/s | 限速/限斜率后的机械速度请求 |
| 31 | speed_truth | rad/s | Plant机械速度，仅供分析 |
| 32 | speed_feedback | rad/s | 机械速度反馈 |
| 33 | position_reference | rad | 机械位置给定 |
| 34 | position_truth | rad | Plant机械位置 |
| 35 | position_feedback | rad | 机械位置反馈 |
| 36 | electrical_angle_truth | rad | Plant电角度 |
| 37 | electrical_angle_feedback | rad | 反馈电角度 |
| 38 | electrical_speed_truth | rad/s | Plant电角速度 |
| 39 | electrical_speed_feedback | rad/s | 反馈电角速度；Allocator使用这个量 |
| 40 | ia_truth | A | a相电流真值 |
| 41 | ib_truth | A | b相电流真值 |
| 42 | ic_truth | A | c相电流真值 |
| 43–45 | inverter_phase_voltage_abc | V | 逆变器三相端电压 |
| 46–48 | deadtime_error_abc | V | 死区引入的三相误差 |
| 49–50 | current_error_dq | A | 参考减采样反馈的dq电流误差 |
| 51 | enable | 1 | 控制器使能；0清状态和参考，不等同硬件停机 |
| 52 | reset | 1 | 1优先清状态和参考 |
| 53 | torque_request | N*m | 分配前转矩请求；正负对应iq方向 |
| 54 | allocated_torque | N*m | 最终参考电流对应的转矩 |
| 55 | torque_residual | N*m | 分配转矩减请求转矩；速度PI回算输入 |
| 56 | id_mtpa | A | MTPA d候选 |
| 57 | iq_mtpa | A | MTPA q候选，未做电压投影 |
| 58 | id_fw | A | 弱磁积分当前状态/候选 |
| 59 | filtered_voltage | V | 有效电压需求经1ms滤波后的值 |
| 60 | voltage_available | V | Allocator的电压约束半径 |
| 61 | predicted_voltage | V | 最终参考的稳态电压模长 |
| 62 | current_margin | A | CurrentMax减参考向量模长 |
| 63 | voltage_margin | V | 可用电压减预测电压；不可行时可为负 |
| 64 | current_limited | 1 | 原请求iq超出当前id下的电流圆 |
| 65 | voltage_limited | 1 | 电流圆夹限后的需求超压，或无可行交集 |
| 66 | feasible | 1 | 当前id的电压/电流/方向区间有交集且控制激活 |
| 67 | fw_active | 1 | 弱磁候选比MTPA更负且控制激活；不是可行标志 |
| 68 | voltage_error | V | max(0,Uavail−FwVoltageMargin)减滤波电压；负值使id更负 |
| 69 | voltage_demand_prev | V | 上一完整拍限幅前PI+FF模长 |
| 70 | speed_pi_torque | N*m | 新速度PI输出，单位N·m |
| 71 | speed_pi_integral | N*m | 新速度PI积分状态，单位N·m |
| 72 | bus_voltage | V | 直流母线；决定可用电压 |
| 73 | model_voltage_demand | V | 请求转矩经电流圆限制后所需电压，未做电压投影 |
| 74 | effective_voltage_demand | V | max(上一拍实际需求,模型需求) |

[运行与调参](../build_process/USAGE.md) · [搭建过程](../build_process/STEPS.md) · [波形分析](../waveform_analysis/ANALYSIS.md) · [模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | currentCfg.Ts / refCfg.FwTs | s | 电流/分配周期与弱磁周期分别配置 |
| $R_s$ | motor.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | motor.Ld / motor.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | motor.Flux | Wb | 直接使用 |
| $P$ | motor.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $V_{dc}$ | inverterCfg.Vdc | V | 直接使用 |

### 本模块局部量

$a_v,b_v,c_v$是电压二次约束系数，避免把局部系数b_v与原表黏性阻尼$B$混淆。$T_{alloc},T_{res}$为分配转矩及其命令残差，均为N·m；不是延迟的实测电磁转矩。
