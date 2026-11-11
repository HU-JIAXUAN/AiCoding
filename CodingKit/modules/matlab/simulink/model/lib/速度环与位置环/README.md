# 速度环与位置环

## 用途

计划步骤11。位置P把位置误差变为速度，叠加速度前馈后统一限速并限制速度斜率。速度PI复用原DiscretePID/Controller，Kd=0，输出q轴电流请求。整定基线为id=0的刚性单惯量。新增SpeedProfile提供带使能/复位的离散限速和非对称斜率限制，供HFI闭环等App共用；原Position、Speed接口及计算保持原语义。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/MotionControl.slx](src/MotionControl.slx) | 已创建 |
| [src/MotionLoopTest.slx](src/MotionLoopTest.slx) | 已创建 |
| [src/SpeedProfileTest.slx](src/SpeedProfileTest.slx) | 已创建 |
| [parameter/speed_profile_parameters.m](parameter/speed_profile_parameters.m) | 已创建 |
| [parameter/PROFILE_PARAMETERS.md](parameter/PROFILE_PARAMETERS.md) | 已创建 |
| [build_process/PROFILE_BUILD.md](build_process/PROFILE_BUILD.md) | 已创建 |
| [waveform_analysis/PROFILE_ANALYSIS.md](waveform_analysis/PROFILE_ANALYSIS.md) | 已创建 |
| [parameter/motion_parameters.m](parameter/motion_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_motion_loop_validation.m](waveform_analysis/run_motion_loop_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| Position.reference / position | 输入 | rad，机械展开位置 | double | 1ms |
| Position.speed_feedforward | 输入 | rad/s | double | 1ms |
| Position.speed_request | 输出 | rad/s | double | 1ms |
| Speed.reference / speed | 输入 | rad/s，机械 | double | 1ms |
| Speed.enable / reset | 输入 | 1 | boolean | 1ms |
| Speed.iq / iq_unsaturated / integral | 输出 | A | double | 1ms |
| SpeedProfile.reference / enable / reset | 输入 | rad/s、0/1、0/1 | double兼容 | 默认50 μs，可配置 |
| SpeedProfile.limited / held_state | 输出 | rad/s | double | 同profileCfg.Ts |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| motionCfg.Ts | s | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.NaturalFrequency | rad/s | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.Damping | 1 | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.Kt | N·m/A | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.Kp | A/(rad/s) | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.Ki | A/rad | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.Kaw | 1/s | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.PositionKp | 1/s | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.SpeedLimit | rad/s | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.AccelerationLimit | rad/s² | [motion_parameters.m](parameter/motion_parameters.m) |
| motionCfg.CurrentLimit | A | [motion_parameters.m](parameter/motion_parameters.m) |
| profileCfg.Ts / Minimum / Maximum / RisingRate / FallingRate | s、rad/s、rad/s² | [speed_profile_parameters.m](parameter/speed_profile_parameters.m)；[完整说明](parameter/PROFILE_PARAMETERS.md) |

## 验证

原3个工况已在R2026b正式路径重跑通过。入口：[run_motion_loop_validation.m](waveform_analysis/run_motion_loop_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开MotionLoopTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

SpeedProfile新增8项独立MIL通过，覆盖限速、非对称斜率、50 μs/1 ms周期、禁能重启及复位优先；独立测试和原3项合计11项，分别保存。正式路径默认输出与受测副本完全一致，原Position/Speed读取快照一致；见[核对记录](waveform_analysis/profile_verification.json)。

未实现完整位置轨迹和在线无扰模式切换。速度PI跟踪自身±8A限制；电压受限时可达转矩尚未反馈外环，将在步骤15与电流分配/弱磁协调。

[模型目录](../../README.md) · [工程入口](../../../README.md)
