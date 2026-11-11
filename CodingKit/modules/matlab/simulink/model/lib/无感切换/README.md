# 无位置传感器捕获与切换

## 用途

在软件启动角与观测器角度之间执行资格检查、平滑过渡和失锁退出。不使用转子真实角度；通过valid、电角速度、电流残差、软件/估算差值及持续时间决定是否接管。库只输出控制角度与状态，电流参考旋转、PI状态跟踪及功率级由App连接。新增HybridFusion分别维护两路资格、包角融合、π分支重接、注入迟滞和故障退出，用于后续HFI↔基波整机组合；与原单向Handover独立。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SensorlessHandover.slx](src/SensorlessHandover.slx) | 已创建 |
| [src/SensorlessHandoverTest.slx](src/SensorlessHandoverTest.slx) | 已创建 |
| [src/HybridFusionTest.slx](src/HybridFusionTest.slx) | 已创建 |
| [parameter/hybrid_fusion_parameters.m](parameter/hybrid_fusion_parameters.m) | 已创建 |
| [parameter/FUSION_PARAMETERS.md](parameter/FUSION_PARAMETERS.md) | 已创建 |
| [build_process/FUSION_BUILD.md](build_process/FUSION_BUILD.md) | 已创建 |
| [build_process/FUSION_USAGE.md](build_process/FUSION_USAGE.md) | 已创建 |
| [waveform_analysis/FUSION_ANALYSIS.md](waveform_analysis/FUSION_ANALYSIS.md) | 已创建 |
| [src/handover_step.m](src/handover_step.m) | 已创建 |
| [parameter/handover_parameters.m](parameter/handover_parameters.m) | 已创建 |
| [build_process/build_sensorless_handover.m](build_process/build_sensorless_handover.m) | 已创建 |
| [waveform_analysis/run_handover_validation.m](waveform_analysis/run_handover_validation.m) | 已创建 |

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| theta_start / theta_hat | 输入 | 电角rad | double | handoverCfg.Ts |
| omega_start / omega_hat | 输入 | 电角rad/s | double | handoverCfg.Ts |
| ready / startup_mode / startup_fault | 输入 | 标志/状态码 | double | handoverCfg.Ts |
| observer_valid / enable / reset | 输入 | 0/1 | double | handoverCfg.Ts |
| residual_norm | 输入 | A | double | handoverCfg.Ts |
| theta_used | 输出 | 电角rad | double | handoverCfg.Ts |
| omega_base / omega_frame | 输出 | 电角rad/s | double | handoverCfg.Ts |
| beta / mode / fault / acquired / run | 输出 | 权重、状态与标志 | double | handoverCfg.Ts |
| qualification_count / loss_count / phase_offset | 输出 | 采样点、采样点、rad | double | handoverCfg.Ts |
| HybridFusion.theta_low / theta_high | 输入 | 电角rad | double | fusionCfg.Ts |
| HybridFusion.omega_low / omega_high | 输入 | 电角rad/s | double | fusionCfg.Ts |
| HybridFusion.low_valid / high_valid / enable / reset | 输入 | 0/1 | double兼容 | fusionCfg.Ts |
| HybridFusion.theta_e / omega_base / omega_frame | 输出 | 电角rad、rad/s、rad/s | double | fusionCfg.Ts |
| HybridFusion.beta / injection_scale / mode / fault及资格标志 | 输出 | 1、枚举及0/1 | double | fusionCfg.Ts |
| HybridFusion.phase_gap / phase_correction及计数 | 输出 | 电角rad、rad/拍、拍 | double | fusionCfg.Ts |

原Handover的mode=4才输出acquired=1，App将其延迟一拍后送给启动模块。startup_mode=1允许零电流窗口的任意相位捕获，此时调用方必须保证电流请求为零；该模块没有电流请求端口，不能自行检查这一条件。

HybridFusion另有8输入/17输出，周期fusionCfg.Ts；输入为低速与基波各自的角度、估速、valid及enable/reset，输出融合角、基准/坐标速度、beta、注入比例及诊断。首次低速资格必须包含磁极极性识别；返回分支只在合格基波支撑下重新确认。它的mode=0/1/2/3/4分别为等待/低速/混合/基波/故障，与原Handover枚举分开。逐端口/单位/27列日志见[融合参数页](parameter/FUSION_PARAMETERS.md)。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| Ts、CaptureTime / BlendTime / LossTime | s | [handover_parameters.m](parameter/handover_parameters.m) |
| MinOmega / MaxSpeedGap | 电角rad/s | 同上 |
| MaxPhaseGap / MaxPhaseInnovation | 电角rad | 同上 |
| MaxResidual / AllowFlying | A / 0或1 | 同上 |
| fusionCfg：重叠区、资格/失效、π分支、注入迟滞与修正率 | 电角rad、rad/s、s及1 | [hybrid_fusion_parameters.m](parameter/hybrid_fusion_parameters.m)；[完整参数](parameter/FUSION_PARAMETERS.md) |

Mask逐实例解析handoverCfg。改时间/周期后调用[refresh_handover_parameters](parameter/refresh_handover_parameters.m)。[参数页](parameter/README.md)说明每个状态、输出和Scope通道；[搭建说明](build_process/STEPS.md)给出过渡和预测公式。

## 验证

R2026b下19项独立MIL通过，结构检查healthy。入口：[run_handover_validation.m](waveform_analysis/run_handover_validation.m)，结果：`results.mat`（运行验证后生成）、[指标](waveform_analysis/metrics.json)、[分析](waveform_analysis/ANALYSIS.md)。原19项逐条回放与新增前记录逐点一致。新增HybridFusion完成30项独立MIL、从原库重新搭建及正式路径默认核对，见[融合结果](waveform_analysis/FUSION_ANALYSIS.md)和[核对记录](waveform_analysis/fusion_verification.json)。两类合计49项，均为解析估计输入；整机电流/转矩、PI坐标衔接、single/SIL与C2000证据另行验证。
