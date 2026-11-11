# 死区误差、补偿与桥臂开关校验

## 用途

计划步骤14。平均误差使用硬电流符号，补偿使用有界平滑符号，并去掉三相共同分量。补偿加在SVPWM前，最终duty继续钳位。短时桥臂以计数器实现开通延迟、立即关断，死区按电流方向选择理想二极管续流。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/Deadtime.slx](src/Deadtime.slx) | 已创建 |
| [src/DeadtimeTest.slx](src/DeadtimeTest.slx) | 已创建 |
| [src/SwitchingLegTest.slx](src/SwitchingLegTest.slx) | 已创建 |
| [parameter/deadtime_parameters.m](parameter/deadtime_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_deadtime_validation.m](waveform_analysis/run_deadtime_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| VoltageError.ia / ib / ic | 输入 | A，流入电机为正 | double | Plant真值，连续 |
| VoltageError.error_a / error_b / error_c | 输出 | V，实际减理想 | double | 继承 |
| Compensation.ia / ib / ic | 输入 | A，采样反馈 | double | 100µs |
| Compensation.comp_a / comp_b / comp_c | 输出 | V | double | 100µs |
| SwitchingLeg.command / current | 输入 | 1 / A，外部施加电流 | double/逻辑兼容 | 0.1µs |
| SwitchingLeg.pole_voltage | 输出 | V，对直流负端 | double | 0.1µs |
| SwitchingLeg.high_gate / low_gate | 输出 | 1 | boolean；记录转double | 0.1µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| deadtimeCfg.DeadTime | s | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.DeviceDrop | V | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.CurrentBlend | A | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.ModelEnable | 1 | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.CompensationEnable | 1 | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.CompensationScale | 1 | [deadtime_parameters.m](parameter/deadtime_parameters.m) |
| deadtimeCfg.SwitchingStep | s | [deadtime_parameters.m](parameter/deadtime_parameters.m) |

## 验证

R2026a下10个工况通过。入口：[run_deadtime_validation.m](waveform_analysis/run_deadtime_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开DeadtimeTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

桥臂电流由外部施加；没有器件结电容、反向恢复及真实零电流换流。开关测试核对假设下的符号、计数和均值，不证明真实过零精度。实际板卡需标定死区、压降和过零平滑区。

[模型目录](../../README.md) · [工程入口](../../../README.md)
