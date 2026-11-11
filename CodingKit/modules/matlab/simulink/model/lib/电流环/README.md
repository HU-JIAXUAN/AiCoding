# dq 电流 PI 与电压限制

## 用途

计划步骤08。两个轴使用独立增益与积分状态，组合为定长向量。现有 DiscretePID 只有内部限幅回算；本模块补充最终电压限制残差输入，未修改旧PID接口。PI与电压限制分开，前馈加在共同限制之前。新增FrameTrackingPI用于额外坐标修正和前馈接入时的积分状态转换；保存旧误差、比例和前馈贡献，保留新的真实误差比例响应。它与原TrackingPI并列，接管公式见[搭建说明](build_process/FRAME_TRACKING.md)。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/CurrentControl.slx](src/CurrentControl.slx) | 已创建 |
| [src/CurrentLoopTest.slx](src/CurrentLoopTest.slx) | 已创建 |
| [src/CurrentPIProbeTest.slx](src/CurrentPIProbeTest.slx) | 已创建 |
| [src/FrameTrackingPITest.slx](src/FrameTrackingPITest.slx) | 已创建 |
| [src/frame_pi_compute.m](src/frame_pi_compute.m) | 已创建 |
| [src/frame_pi_update.m](src/frame_pi_update.m) | 已创建 |
| [build_process/FRAME_TRACKING.md](build_process/FRAME_TRACKING.md) | 已创建 |
| [parameter/FRAME_TRACKING.md](parameter/FRAME_TRACKING.md) | 已创建 |
| [waveform_analysis/FRAME_TRACKING.md](waveform_analysis/FRAME_TRACKING.md) | 已创建 |
| [parameter/current_parameters.m](parameter/current_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_current_loop_validation.m](waveform_analysis/run_current_loop_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| TrackingPI.error_dq | 输入 | A，[d;q] | double[2] | 100µs |
| TrackingPI.voltage_residual | 输入 | V，[d;q] | double[2] | 100µs |
| TrackingPI.enable / reset | 输入 | 1 | boolean兼容 | 100µs |
| TrackingPI.voltage_pi / integral_state | 输出 | V，[d;q] | double[2] | 100µs |
| FrameTrackingPI.error_dq / voltage_residual / feedforward_dq | 输入 | A / V / V，[d;q] | double[2] | currentCfg.Ts；新测试50µs |
| FrameTrackingPI.delta_extra / track / enable / reset | 输入 | rad / 1 / 1 / 1 | double | currentCfg.Ts |
| FrameTrackingPI.voltage_pi / integral_base / integral_state | 输出 | V，[d;q] | double[2] | currentCfg.Ts |
| VoltageLimit.voltage_request | 输入 | V，[d;q] | double[2] | 继承 |
| VoltageLimit.voltage_limited / scale | 输出 | V[2] / 1 | double | 继承 |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| currentCfg.Ts | s | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.BandwidthHz | Hz | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.Kpd | V/A | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.Kpq | V/A | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.Kid | V/(A·s) | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.Kiq | V/(A·s) | [current_parameters.m](parameter/current_parameters.m) |
| currentCfg.Kaw | 1/s | [current_parameters.m](parameter/current_parameters.m) |

## 验证

原6个工况已在R2026b重新运行通过；新坐标跟踪PI另通过10项独立MIL，包含不相等增益下的物理电压连续性、持续track期间比例响应、前馈、正负回算和复位。见[新验证分析](waveform_analysis/FRAME_TRACKING.md)、`frame_pi_results.mat`（运行验证后生成）和[指标](waveform_analysis/frame_pi_metrics.json)。新测试的50µs配置与Scope见[参数页](parameter/FRAME_TRACKING.md)，原测试保持100µs。原入口：[run_current_loop_validation.m](waveform_analysis/run_current_loop_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开CurrentLoopTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

double、100µs MIL。500Hz是教学整定起点，延迟变化后需重新检查。直接电流模式允许故意超量给定做电压饱和测试，不是实机电流保护器。A中的代码配置失败保留为历史记录；B补齐Simulink Coder后，临时副本已通过编译分析并生成GRT/C源码，见[代码报告](../../../docs/validation/code_generation.json)。尚未构建可执行程序或执行SIL。

[模型目录](../../README.md) · [工程入口](../../../README.md)
