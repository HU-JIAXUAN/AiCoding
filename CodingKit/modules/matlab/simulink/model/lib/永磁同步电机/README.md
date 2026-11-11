# PMSM 数学电机与刚性负载

## 用途

步骤06的PMSMPlant为常参数电气/机械积木；其独立测试台分别驱动两部分，输入第4列为独立机械转矩。新增PMSMHighFrequencyPlant将非线性电气与机械运动闭合，提供凸极、增量电感、交叉电感和磁极偏置饱和响应，供HFI与极性辨识复用。原有对象使用各自参数入口，原有测试保留。

新增PMSMBridgePlant把线性PMSM与平均PWM/关断二极管桥耦合，用于区分开路滑行、整流续流和主动短路，为后续带速捕获提供对象基础。它不使用高频对象的饱和磁链。

新增PMSMBridgeBusPlant库/Test，以第四输入接收运行时母线电压；其余16个输出和物理内核共用。10项检查包含6项正常/数值与4项拒绝，恒48/36V与原桥逐点一致；[参数与九组Scope](parameter/BRIDGE_BUS_PARAMETERS.md)、[运行](build_process/BRIDGE_BUS_USAGE.md)、[波形分析](waveform_analysis/BRIDGE_BUS_ANALYSIS.md)随模块保存。它为后续弱磁App的母线阶跃提供对象，尚未计为弱磁整机验证。

EKF/后续UKF共用的四状态SPMSM过程/测量M函数也在本模块维护，入口和量纲见[过程参数页](parameter/SENSORLESS_PARAMETERS.md)。它不新增SLX，独立连续dq轨迹生成器用于观测器测试；原IPMSM和高频对象参数保持各自定义。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/PMSMPlant.slx](src/PMSMPlant.slx) | 已创建 |
| [src/PMSMPlantTest.slx](src/PMSMPlantTest.slx) | 已创建 |
| [src/PMSMHighFrequencyPlant.slx](src/PMSMHighFrequencyPlant.slx) | 已创建 |
| [src/PMSMHighFrequencyPlantTest.slx](src/PMSMHighFrequencyPlantTest.slx) | 已创建 |
| [src/PMSMBridgePlant.slx](src/PMSMBridgePlant.slx) | 已创建 |
| [src/PMSMBridgePlantTest.slx](src/PMSMBridgePlantTest.slx) | 已创建 |
| [src/PMSMBridgeBusPlant.slx](src/PMSMBridgeBusPlant.slx) | 已创建 |
| [src/PMSMBridgeBusPlantTest.slx](src/PMSMBridgeBusPlantTest.slx) | 已创建 |
| [parameter/bridge_bus_test_parameters.m](parameter/bridge_bus_test_parameters.m) | 已创建 |
| [parameter/BRIDGE_BUS_PARAMETERS.md](parameter/BRIDGE_BUS_PARAMETERS.md) | 已创建 |
| [build_process/build_pmsm_bridge_bus.m](build_process/build_pmsm_bridge_bus.m) | 已创建 |
| [build_process/BRIDGE_BUS_BUILD.md](build_process/BRIDGE_BUS_BUILD.md) | 已创建 |
| [build_process/BRIDGE_BUS_USAGE.md](build_process/BRIDGE_BUS_USAGE.md) | 已创建 |
| [waveform_analysis/BRIDGE_BUS_ANALYSIS.md](waveform_analysis/BRIDGE_BUS_ANALYSIS.md) | 已创建 |
| [waveform_analysis/bus_verification.json](waveform_analysis/bus_verification.json) | 已创建 |
| [parameter/pmsm_bridge_parameters.m](parameter/pmsm_bridge_parameters.m) | 已创建 |
| [parameter/bridge_test_parameters.m](parameter/bridge_test_parameters.m) | 已创建 |
| [parameter/BRIDGE_PARAMETERS.md](parameter/BRIDGE_PARAMETERS.md) | 已创建 |
| [build_process/build_pmsm_bridge_plant.m](build_process/build_pmsm_bridge_plant.m) | 已创建 |
| [build_process/BRIDGE_BUILD.md](build_process/BRIDGE_BUILD.md) | 已创建 |
| [build_process/BRIDGE_USAGE.md](build_process/BRIDGE_USAGE.md) | 已创建 |
| [waveform_analysis/BRIDGE_ANALYSIS.md](waveform_analysis/BRIDGE_ANALYSIS.md) | 已创建 |
| [waveform_analysis/bridge_verification.json](waveform_analysis/bridge_verification.json) | 已创建 |
| [src/pmsm_hf_dynamics.m](src/pmsm_hf_dynamics.m) | 已创建 |
| [src/pmsm_hf_output.m](src/pmsm_hf_output.m) | 已创建 |
| [parameter/pmsm_hf_parameters.m](parameter/pmsm_hf_parameters.m) | 已创建 |
| [parameter/HF_PARAMETERS.md](parameter/HF_PARAMETERS.md) | 已创建 |
| [build_process/HF_BUILD.md](build_process/HF_BUILD.md) | 已创建 |
| [build_process/HF_USAGE.md](build_process/HF_USAGE.md) | 已创建 |
| [waveform_analysis/run_hf_plant_validation.m](waveform_analysis/run_hf_plant_validation.m) | 已创建 |
| [waveform_analysis/HF_ANALYSIS.md](waveform_analysis/HF_ANALYSIS.md) | 已创建 |
| [parameter/pmsm_parameters.m](parameter/pmsm_parameters.m) | 已创建 |
| [parameter/pmsm_sensorless_parameters.m](parameter/pmsm_sensorless_parameters.m) | 已创建 |
| [src/pmsm_sensorless_step.m](src/pmsm_sensorless_step.m) | 已创建 |
| [src/pmsm_sensorless_measurement.m](src/pmsm_sensorless_measurement.m) | 已创建 |
| [build_process/spmsm_estimation_fixture.m](build_process/spmsm_estimation_fixture.m) | 已创建 |
| [parameter/SENSORLESS_PARAMETERS.md](parameter/SENSORLESS_PARAMETERS.md) | 已创建 |
| [waveform_analysis/SENSORLESS_PROCESS.md](waveform_analysis/SENSORLESS_PROCESS.md) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_pmsm_plant_validation.m](waveform_analysis/run_pmsm_plant_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| Electrical.vd / vq | 输入 | V | double | 连续 |
| Electrical.omega_e | 输入 | rad/s，电角速度 | double | 连续 |
| Electrical.id / iq | 输出 | A，相峰值 | double | 连续 |
| Electrical.torque | 输出 | N·m | double | 连续 |
| Mechanical.torque / load_torque | 输入 | N·m，有符号 | double | 连续 |
| Mechanical.omega_m / omega_e | 输出 | rad/s，机械/电 | double | 连续 |
| Mechanical.theta_m / theta_e | 输出 | rad，机械展开/电角包裹 | double | 连续 |

HFPMSM接口如下，详细端口和六组Scope见[高频对象参数页](parameter/HF_PARAMETERS.md)。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha / u_beta | 输入 | V | double | 连续对象，外部电压可离散保持 |
| load_torque | 输入 | N·m | double | 连续 |
| i_alpha / i_beta、id / iq | 输出 | A，相峰值 | double | 连续；测试台50 μs采样 |
| theta_e / omega_e | 输出 | 电角rad / rad/s | double | 连续；真实量仅供评估 |
| torque / incremental_ld / psi_d / psi_q | 输出 | N·m / H / Wb / Wb | double | 连续 |

原桥耦合对象有3输入/16输出，均double、默认5μs；完整输出和33列记录见[BRIDGE_PARAMETERS.md](parameter/BRIDGE_PARAMETERS.md)。新增BridgeBusMotor在末尾增加第4输入bus_voltage（V，double正有限标量，同步5μs），16输出顺序保持一致，新Test为34列；见[运行时母线参数页](parameter/BRIDGE_BUS_PARAMETERS.md)。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| BridgeMotor.duty_abc / mode / load_torque | 输入 | 1 / 状态0..2 / N·m | double向量3 / 标量 / 标量 | 5μs |
| current_ab / phase_current | 输出 | A | double向量2 / 3，当前状态 | 5μs |
| phase_voltage / voltage_ab / pole_voltage / neutral_voltage | 输出 | V | double向量3 / 2 / 3 / 标量，区间等效量 | 5μs |
| speed_mechanical / theta_e / torque | 输出 | 机械rad/s / 电角rad / N·m | double标量 | 5μs |
| dc_current / diode_states / bridge_loss / equation_residual | 输出 | A / −1,0,+1 / W / V | double标量 / 向量3 / 标量 / 标量 | 5μs |
| magnetic_energy / kinetic_energy / next_phase_current | 输出 | J / J / A | double标量 / 标量 / 向量3 | 5μs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| pmsmCfg.Rs | Ω | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Ld | H | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Lq | H | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Flux | Wb | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.PolePairs | 1 | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.J | kg·m² | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.B | N·m·s/rad | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Id0 | A | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Iq0 | A | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Speed0 | rad/s | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| pmsmCfg.Position0 | rad | [pmsm_parameters.m](parameter/pmsm_parameters.m) |
| bridgeCfg.* | 逐字段SI | [pmsm_bridge_parameters.m](parameter/pmsm_bridge_parameters.m) |
| bridgeCfg / bridgeTestCfg验证实例 | 逐字段SI或状态 | [bridge_test_parameters.m](parameter/bridge_test_parameters.m) |
| 运行时母线BusTimes / BusValues及独立工况 | s / V及逐字段SI | [bridge_bus_test_parameters.m](parameter/bridge_bus_test_parameters.m) |

高频/饱和对象入口为[pmsm_hf_parameters.m](parameter/pmsm_hf_parameters.m)，测试输入为[hf_plant_test_parameters.m](parameter/hf_plant_test_parameters.m)，派生向量由[refresh_pmsm_hf_parameters.m](parameter/refresh_pmsm_hf_parameters.m)刷新。

四状态过程的Ts/Rs/L/Flux/PolePairs定义在[pmsm_sensorless_parameters.m](parameter/pmsm_sensorless_parameters.m)，默认Ts=50 μs、L取原Ld=1 mH。输入/输出和过程Jacobian见[参数页](parameter/SENSORLESS_PARAMETERS.md)。

## 验证

R2026a下5个工况通过。入口：[run_pmsm_plant_validation.m](waveform_analysis/run_pmsm_plant_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开PMSMPlantTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

上述PMSMPlant为线性磁路、恒定R/L/磁链与单惯量模型。新增高频对象已在R2026b完成14项独立物理MIL，正式目录全部重跑通过；[结果与分析](waveform_analysis/HF_ANALYSIS.md)保存解析解、正负脉冲、无凸极退化、自由位移及磁链Jacobian检查。

高频对象的磁链曲线为合成示意模型，参数没有实测辨识或有限元拟合来源；尚未包含完整HFI观测器，也没有铁耗、磁滞、齿槽、弹性轴与温度模型。

共用SPMSM过程新增4个过程Jacobian点及4个测量Jacobian点的纯M检查通过，见[SENSORLESS_PROCESS.md](waveform_analysis/SENSORLESS_PROCESS.md)。它们不计作物理MIL；EKF独立轨迹25项结果在[EKF模块](../观测器/扩展卡尔曼/README.md)。

桥耦合对象新增15项R2026b验证（14物理动态+1错误输入拒绝），另有18组纯M/480点独立物理核对；[分析](waveform_analysis/BRIDGE_ANALYSIS.md)、[源/重建/正式路径检查](waveform_analysis/bridge_verification.json)随模块维护。旧App尚未改用此对象，不能把此结果计为旧App安全关断或带速捕获完成。

运行时母线新增10项模型检查（6项正常/数值、4项拒绝），恒48/36V共672,056个物理输出数值与原桥差0；默认34列、九组Scope、当前M重建和正式路径重放见[分析](waveform_analysis/BRIDGE_BUS_ANALYSIS.md)及[证据](waveform_analysis/bus_verification.json)。C2000、SIL和弱磁闭环不在本项验证结论内。

[模型目录](../../README.md) · [工程入口](../../../README.md)
