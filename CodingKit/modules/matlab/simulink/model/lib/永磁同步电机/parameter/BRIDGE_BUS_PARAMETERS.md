# 运行时母线桥模型：参数与通道

[PMSMBridgeBusPlant.slx](../src/PMSMBridgeBusPlant.slx)导出`BridgeBusMotor`，供其他模型链接调用；[PMSMBridgeBusPlantTest.slx](../src/PMSMBridgeBusPlantTest.slx)用于独立运行验证。物理计算继续使用[pmsm_bridge_step.m](../src/pmsm_bridge_step.m)与[pmsm_bridge_output.m](../src/pmsm_bridge_output.m)。

## 配置参数

可执行入口为[bridge_bus_test_parameters.m](bridge_bus_test_parameters.m)，返回`bridgeCfg`与`bridgeTestCfg`。基础电机/桥参数仍来自[pmsm_bridge_parameters.m](pmsm_bridge_parameters.m)；完整基础字段见[BRIDGE_PARAMETERS.md](BRIDGE_PARAMETERS.md)。修改默认M文件后，加载Test并执行`initialize_bridge_bus_test('PMSMBridgeBusPlantTest')`，随后点击Run。单次覆盖用`run_bridge_bus_case(p)`。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| bridgeCfg.Ts | 5e-6 | s | 物理离散步长；pmsm_bridge_parameters.m |
| bridgeCfg.Rs / Ld / Lq / Flux | 0.5 / 0.001 / 0.0012 / 0.035 | Ω / H / H / Wb | 原线性IPMSM实例，定义文件同上 |
| bridgeCfg.PolePairs / J / B | 4 / 5e-4 / 1e-4 | 计数 / kg·m² / N·m·s/rad | 电角/机械换算及机械方程 |
| bridgeCfg.Vdc | 48 | V | 基础配置中的名义值；本新库每拍由第四输入覆盖，不是运行时母线信号的来源 |
| bridgeCfg.Speed0 / Position0 | 0 / 0.1 | 机械rad/s / 机械rad | 本Test的初始机械状态；bridge_bus_test_parameters.m |
| bridgeCfg.Id0 / Iq0 | 0 / 0 | A | 初始dq电流；刷新函数转换为静止坐标State0 |
| bridgeTestCfg.Duration | 0.06 | s | StopTime，定义在本地入口 |
| bridgeTestCfg.Duty | [0.6,0.4,0.5] | 1 | 三桥臂平均PWM占空比 |
| bridgeTestCfg.ModeTimes / ModeValues | 0 / 1 | s / 状态 | 默认一直PWM；0全关断、1平均PWM、2主动短路 |
| bridgeTestCfg.LoadTorque | 0 | N·m | 有符号外负载 |
| bridgeTestCfg.BusTimes | [0,0.02,0.04] | s | 母线事件时刻，必须落在Ts网格上 |
| bridgeTestCfg.BusValues | [48,24,48] | V | 与BusTimes逐项对应；只允许正有限值 |

改变实际母线波形应修改`BusTimes/BusValues`或第四输入信号。只改`bridgeCfg.Vdc`不会改写已经明确给出的`BusValues`。该模型使用外部规定、可吸收回馈的母线电压，不含电容充放电或供电源内阻状态。

本次新增量沿用[工程符号表](../../../../docs/userdocs/符号定义表.md)：

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $V_{dc}$ | bus_voltage；bridgeBusStim第6列 | V | 数值直接使用，不换算 |
| $i_{dc}$ | dc_current，第8输出 | A | 数值直接使用；正值从母线流向电机，负值回馈母线 |
| $\theta_r$ | theta_e，第6输出 | 电角rad | 数值直接使用；不是机械初始位置Position0 |
| $P$ | bridgeCfg.PolePairs | 计数 | 数值不换算；原书单位栏空白，本表不修改原表 |

## 输入信号

| 端口 | 名称 | 单位/类型 | 来源与用途 |
|---|---|---|---|
| 1 | duty_abc | 1，double[3] | a/b/c平均占空比；仅mode=1时作为PWM驱动 |
| 2 | mode | double标量，0/1/2 | 全关断二极管求解 / 平均PWM / 主动短路 |
| 3 | load_torque | N·m，double标量 | 机械方程外负载 |
| 4 | bus_voltage | V，double正有限标量 | 当前区间的母线电压，所有桥状态共用 |

[bridge_bus_stimulus.m](../build_process/bridge_bus_stimulus.m)生成六列：1–3为占空比，4为mode，5为负载，6为实际母线电压。FromWorkspace按5μs读取并保持，不插值。

## 过程变量

| 名称 | 单位/初值 | 所在块 | 作用 |
|---|---|---|---|
| cfg.Vector | 混合SI，17×1 | Settings | 原桥/电机固定配置向量 |
| settings(9) | V，来自第四输入 | BusSettings | 每拍替换名义Vdc；其余16个配置值保持原值 |
| PhysicalState | [A,A,机械rad/s,机械rad]，cfg.State0 | UnitDelay | 保存当前物理状态；母线变化不重置状态 |
| next / next_phase_current | A及机械状态 / A[3] | Step | 当前区间求出的下一状态及下一拍电流诊断 |
| BusPower | W | Product | 当前Vdc乘本区间dc_current；不使用固定Gain |
| TerminalPower | W | DotProduct | 区间相电压与next_phase_current点积 |

## 输出信号

16个输出的顺序与原BridgeMotor相同，见[基础端口表](BRIDGE_PARAMETERS.md)。当前电流由`PhysicalState[k]`测量；电压、母线电流、二极管状态等是区间[k,k+1]的等效量。`next_phase_current`用于区间功率核对，不应当成本拍电流反馈。全部为double，默认5μs。

ToWorkspace变量仍为`bridge_trace`，本Test扩展为34列。运行器返回`r.time`、`r.trace`、`r.columns`和实际参数/输入。

| 列 | 名称 | 单位 |
|---|---|---|
| 1–3 / 4 / 5 / 6 | duty_abc / mode / load_torque / Vdc | 1 / 状态 / N·m / V |
| 7–8 | current_ab | A |
| 9–11 | phase_current | A |
| 12–14 / 15–16 | phase_voltage / voltage_ab | V |
| 17 / 18 / 19 / 20 | speed_mechanical / theta_e / torque / dc_current | 机械rad/s / 电角rad / N·m / A |
| 21–23 | diode_states，a/b/c | −1/0/+1；上二极管/不导通/下二极管 |
| 24 / 25 / 26 / 27 | magnetic_energy / kinetic_energy / bridge_loss / equation_residual | J / J / W / V |
| 28–30 / 31 / 32–34 | next_phase_current / neutral_voltage / pole_voltage | A / V / V |

## Scope 通道

每个Scope只有一个向量输入。序号按该向量元素展开，来源已由原生端口连接核对。

| Scope | 通道顺序 | 来源 | 单位/观察内容 |
|---|---|---|---|
| PhaseCurrentScope | 1 ia，2 ib，3 ic | Plant.y2 | A；当前连续状态电流 |
| PhaseVoltageScope | 1 ua，2 ub，3 uc | Plant.y3 | V；区间等效相电压 |
| MechanicalSpeedScope | 1 omega_m | Plant.y5 | 机械rad/s；自由转子或外部规定速度 |
| EnergyScope | 1磁储能，2动能 | Plant.y10 / y11 | J；状态能量 |
| PowerScope | 1母线功率，2端口功率，3桥损耗 | BusPower / TerminalPower / Plant.y12 | W；符号与区间功率平衡 |
| BridgeModeScope | 1 mode，2–4二极管状态a/b/c | Inputs.y4 / Plant.y9 | 状态；区分关断、PWM、主动短路 |
| EquationResidualScope | 1方程残差 | Plant.y13 | V；离散平衡求解残差 |
| BusVoltageScope | 1 Vdc | Inputs.y6 | V；实际第四输入，不是名义参数 |
| BusCurrentScope | 1 idc | Plant.y8 | A；负值表示回馈 |

没有新增角度或转矩Scope；这些量在34列日志中。九组Scope不能视为完整弱磁App的波形，后续App还需记录估算资格、id/iq参考和限压状态。

[模块入口](../README.md) · [运行方法](../build_process/BRIDGE_BUS_USAGE.md)
