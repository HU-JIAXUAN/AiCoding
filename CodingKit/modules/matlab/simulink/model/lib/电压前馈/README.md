# dq 解耦与反电势前馈

## 用途

计划步骤13。与本项目Park方向一致：vd_ff=−omega_e·Lq·iq，vq_ff=omega_e·(Ld·id+Flux)。使用同帧反馈，在共同电压限制前只相加一次。整机控制禁能/复位时同时清零PI与前馈请求。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/DQFeedforward.slx](src/DQFeedforward.slx) | 已创建 |
| [src/FeedforwardTest.slx](src/FeedforwardTest.slx) | 已创建 |
| [parameter/feedforward_parameters.m](parameter/feedforward_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_feedforward_validation.m](waveform_analysis/run_feedforward_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| Feedforward.id / iq | 输入 | A，反馈电流 | double | 100µs |
| Feedforward.omega_e | 输入 | rad/s，电角速度 | double | 100µs |
| Feedforward.vd_ff / vq_ff | 输出 | V | double | 100µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| feedforwardCfg.Enable | 1 | [feedforward_parameters.m](parameter/feedforward_parameters.m) |
| feedforwardCfg.ParameterScale | 1 | [feedforward_parameters.m](parameter/feedforward_parameters.m) |

## 验证

R2026a下5个工况通过。入口：[run_feedforward_validation.m](waveform_analysis/run_feedforward_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开FeedforwardTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

线性磁链模型；不含交叉饱和磁链图、角度预测或PWM生效时刻外推。强制转速实验表示外部原动机维持转速，自由机械积分器不参与该速度。

[模型目录](../../README.md) · [工程入口](../../../README.md)
