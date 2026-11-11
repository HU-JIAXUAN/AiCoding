# 共同实验与整机装配

## 用途

本App归Sensor，控制使用仿真位置/速度反馈；本目录归类不代表已完成真实位置传感器接入。通用积木继续引用model/lib。

计划步骤07、12，并装配08–14。四个装配子系统为FeedbackStage、MotionStage、CurrentStage、VoltageStage。保留对象真值和控制反馈。run_motor_case通过SimulationInput覆盖一轮实验，保存实际参数、输入、完整数据和通道名。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/MotorExperiment.slx](src/MotorExperiment.slx) | 已创建 |
| [parameter/experiment_parameters.m](parameter/experiment_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_experiment_validation.m](waveform_analysis/run_experiment_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| 位置/速度/电流配置给定 | 输入 | rad / rad/s / A | double | 外环1ms，电流100µs |
| LoadTorque | 输入 | N·m，有符号负载 | double | 100µs |
| Enable / Reset | 输入 | 1，控制器使能/同步复位 | boolean | 100µs |
| trace | 记录输出 | 逐列SI单位 | double[52] | 100µs |
| 状态、反馈、duty与残差 | 过程/输出 | 见Scope表 | double | 连续或明确采样周期 |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| experimentCfg.Step | s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.LogTs | s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.Duration | s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.Mode | 枚举 | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.UseInverter | 1 | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.UseTiming | 1 | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.UseMechanical | 1 | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.ImposedElectricalSpeed | rad/s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.IdReference | A | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.IqReference | A | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.IqInitial | A | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.SpeedReference | rad/s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.SpeedInitial | rad/s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.PositionReference | rad | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.PositionInitial | rad | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.CommandTime | s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.LoadTorque | N·m | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.LoadTime | s | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.Enable | 1 | [experiment_parameters.m](parameter/experiment_parameters.m) |
| experimentCfg.Reset | 1 | [experiment_parameters.m](parameter/experiment_parameters.m) |

## 验证

R2026a下9个工况通过。入口：[run_experiment_validation.m](waveform_analysis/run_experiment_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开MotorExperiment.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

double MIL、理想同步反馈和简化功率级。没有完整启停监督器、门极保护和实际ADC/PWM资源绑定。MTPA/弱磁、算法替换和目标验证仍在步骤15–18。

[模型目录](../../../README.md) · [工程入口](../../../../README.md)

[Sensor分类](../README.md) · [App分类](../../README.md)
