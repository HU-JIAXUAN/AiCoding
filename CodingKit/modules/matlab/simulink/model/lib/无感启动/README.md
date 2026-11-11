# 无位置传感器启动序列

## 用途

生成零电流带速捕获窗口、两阶段对齐、限幅I-f爬升和捕获等待序列。输出软件电流矢量角度与电流请求，不使用转子真实角度，也不直接控制逆变器。该角度是定子电流矢量方向，虚拟d电流为正、虚拟q为0；它不是转子位置测量值。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SensorlessStartup.slx](src/SensorlessStartup.slx) | 已创建 |
| [src/SensorlessStartupTest.slx](src/SensorlessStartupTest.slx) | 已创建 |
| [src/startup_step.m](src/startup_step.m) | 已创建 |
| [parameter/startup_parameters.m](parameter/startup_parameters.m) | 已创建 |
| [build_process/build_sensorless_startup.m](build_process/build_sensorless_startup.m) | 已创建 |
| [waveform_analysis/run_startup_validation.m](waveform_analysis/run_startup_validation.m) | 已创建 |

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| enable / reset / acquired | 输入 | 0/1 | double | startupCfg.Ts |
| direction | 输入 | +1/-1 | double | startupCfg.Ts |
| theta_start / omega_start | 输出 | 电角rad / rad/s | double | startupCfg.Ts |
| id_start / iq_start | 输出 | A，软件电流矢量坐标 | double | startupCfg.Ts |
| ready / mode / fault | 输出 | 标志/状态码 | double | startupCfg.Ts |
| elapsed | 输出 | s，当前阶段计时 | double | startupCfg.Ts |

acquired由上层切换模块的AUTO标志延迟一拍提供。ready只表示软件启动过程允许检查捕获，不表示电机实际已启动或观测器已锁定。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| Ts、各阶段时间、Theta0 | s、rad | [startup_parameters.m](parameter/startup_parameters.m) |
| AlignCurrent / StartupCurrent | A | 同上 |
| FinalOmega / MinCaptureOmega | 电角rad/s | 同上 |

每个库实例的Startup configuration填写完整配置结构表达式。修改周期/时间后先运行[refresh_startup_parameters](parameter/refresh_startup_parameters.m)。完整配置、过程变量和Scope说明见[参数页](parameter/README.md)。

## 验证

R2026b下10项独立MIL通过，结构检查healthy。入口：[run_startup_validation.m](waveform_analysis/run_startup_validation.m)，保存`results.mat`（运行验证后生成）、[指标](waveform_analysis/metrics.json)和[分析](waveform_analysis/ANALYSIS.md)。检查时序、幅值、复位及首个故障锁存；真实电机启动能力在后续App中单独验证。

## 独立 I-f / V/f 公用命令

[OpenLoopDrive.slx](src/OpenLoopDrive.slx) 是持续运行的开环命令库，[OpenLoopDriveTest.slx](src/OpenLoopDriveTest.slx) 是独立 Test。它将软件角度、频率斜坡、幅值、启动观察和过流逻辑复用给 [I-f](../../app_models/Sensorless/sensorless_if/README.md) 与 [V/f](../../app_models/Sensorless/sensorless_vf/README.md)；上面的 SensorlessStartup 仍负责有限时长的 FOC 启动序列。OpenLoopDrive 无 acquired 输入，也没有估计或接管状态。

[接口与 Scope](parameter/OPEN_LOOP_PARAMETERS.md) · [搭建、运行](build_process/OPEN_LOOP_BUILD.md) · [独立验证](waveform_analysis/OPEN_LOOP_ANALYSIS.md)
