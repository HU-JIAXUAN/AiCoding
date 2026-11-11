# 控制采样与执行时序

## 用途

计划步骤10。Feedback和Actuation均先采样保持，再配置整数拍延迟。UseTiming=0选择保持值，仍保留离散采样；UseTiming=1选择延迟值。整机使用共同的电流/角度反馈帧。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/ControlTiming.slx](src/ControlTiming.slx) | 已创建 |
| [src/TimingTest.slx](src/TimingTest.slx) | 已创建 |
| [parameter/timing_parameters.m](parameter/timing_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_timing_validation.m](waveform_analysis/run_timing_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| Feedback.truth | 输入 | 调用者定义 | double标量/定长向量 | 连续或更快 |
| Feedback.sampled / feedback | 输出 | 保留输入单位 | double | 100µs |
| Actuation.command | 输入 | 调用者定义 | double标量/定长向量 | 控制周期 |
| Actuation.held / applied | 输出 | 保留输入单位 | double | 100µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| timingCfg.Ts | s | [timing_parameters.m](parameter/timing_parameters.m) |
| timingCfg.FeedbackTicks | 拍 | [timing_parameters.m](parameter/timing_parameters.m) |
| timingCfg.ActuationTicks | 拍 | [timing_parameters.m](parameter/timing_parameters.m) |

## 验证

R2026a下3个工况通过。入口：[run_timing_validation.m](waveform_analysis/run_timing_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开TimingTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

没有ADC量化、采样窗口、PWM载波相位、通信抖动与真实ISR；不同传感器年龄尚未分开配置。不能用整数拍仿真证明C2000的真实截止时间。

[模型目录](../../README.md) · [工程入口](../../../README.md)
