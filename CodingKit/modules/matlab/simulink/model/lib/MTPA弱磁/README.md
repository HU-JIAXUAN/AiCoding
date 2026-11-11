# MTPA 与弱磁电流分配

## 用途

步骤15。先由 MTPA 生成电流候选，再由带滤波、限斜率和负 id 边界的积分器实现弱磁，最后统一分配 id/iq 与转矩。使用基础 Simulink 块，沿用峰值 dq、SI、d 轴磁链对齐约定。模型支持常参数 Lq≥Ld，包含 Lq=Ld 的 id=0 情形。

整机单独归[App/mtpa_fw](../../app_models/Sensor/mtpa_fw/README.md)。该入口把速度 PI 改为输出 N·m，并将分配转矩残差返回积分器；原 [MotorExperiment](../../app_models/Sensor/experiment/README.md) 保留原行为。参数是教学夹具；CurrentMax、IdMin 是声明的仿真边界。这里没有磁饱和查表、MTPV、实机退磁边界或 C2000 部署结果。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/CurrentReference.slx](src/CurrentReference.slx) | 已创建 |
| [src/CurrentReferenceTest.slx](src/CurrentReferenceTest.slx) | 已创建 |
| [parameter/mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_mtpa_fw_validation.m](waveform_analysis/run_mtpa_fw_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数与 Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

以下为 Allocator 的六个输入；完整19个输出见参数说明。弱磁内部状态1ms更新，分配运算随电流拍100µs更新。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| torque_request | 输入 | N·m | double | 100µs，外环1ms保持 |
| omega_e | 输入 | rad/s，带符号电角速度 | double | 100µs |
| bus_voltage | 输入 | V，非负 | double | 100µs |
| voltage_demand_prev | 输入 | V，上一完整拍的限幅前 PI+FF 模长 | double | 100µs |
| enable / reset | 输入 | 1 | double/逻辑兼容 | 100µs |
| id_reference / iq_reference | 输出 | A，相峰值 | double | 100µs |
| allocated_torque / torque_residual | 输出 | N·m | double | 100µs |
| feasible / current_limited / voltage_limited / fw_active | 输出 | 1 | boolean，记录转 double | 100µs |
| id_fw / filtered_voltage / voltage_error | 输出 | A / V / V | double | 1ms保持 |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| refCfg.CurrentMax / IdMin | A | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.VoltageReserve / MinDuty | 1 | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.FwVoltageMargin | V | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.FwTs / FilterTau | s | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.FwKi / IdSlew | A/(V·s) / A/s | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.SpeedKp / SpeedKi / SpeedKaw | N·m·s/rad / N·m/rad / 1/s | [mtpa_fw_parameters.m](parameter/mtpa_fw_parameters.m) |
| refCfg.IdTable / TorqueGrid | A / N·m | [refresh_mtpa_tables.m](parameter/refresh_mtpa_tables.m) |
| pmsmCfg / 其他模块配置 | SI | [配置装配](parameter/reference_case_parameters.m)，引用原模块定义 |

## 验证

MATLAB R2026a，double MIL；7项 MTPA、11项弱磁组件、7项整机工况，共25项。执行入口为 [run_mtpa_fw_validation.m](waveform_analysis/run_mtpa_fw_validation.m)，数据/指标与 [分析](waveform_analysis/ANALYSIS.md) 同目录保存。运行、临时调参和 Scope 操作见 [USAGE.md](build_process/USAGE.md)。

可行标志只针对选定 id 下的常参数稳态约束；为 false 时没有电压可行保证。参考电流受限不等于实际瞬态电流受硬保护。分配转矩不是实测转矩，也不是所有 id 上的全局最大转矩。

[模型目录](../../README.md) · [工程入口](../../../README.md)
