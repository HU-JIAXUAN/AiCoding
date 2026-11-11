# 离散相位 PLL

## 用途

跟踪输入电角相位，输出同一采样时刻的估算角度、带符号电角速度及有效标志。它是可复用相位跟踪积木，不从电流/电压直接观测转子，也不代表无位置传感器整机闭环完成。使用 MATLAB R2026b 构建。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/AngleTracking.slx](src/AngleTracking.slx) | 已创建 |
| [src/AngleTrackingTest.slx](src/AngleTrackingTest.slx) | 已创建 |
| [src/AngleTrackingInstancesTest.slx](src/AngleTrackingInstancesTest.slx) | 已创建 |
| [实例隔离验证](waveform_analysis/run_pll_instance_validation.m) | 已创建 |
| [参数定义](parameter/angle_tracking_parameters.m) | 已创建 |
| [搭建脚本](build_process/build_angle_tracking.m) | 已创建 |
| [验证脚本](waveform_analysis/run_angle_tracking_validation.m) | 已创建 |

[搭建步骤](build_process/STEPS.md) · [运行与调参](build_process/USAGE.md) · [波形分析](waveform_analysis/ANALYSIS.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| phase | 输入 | 电角 rad，允许包角 | double | pllCfg.Ts |
| magnitude | 输入 | 调用方声明的幅值单位 | double，非负 | pllCfg.Ts |
| enable / reset | 输入 | 0/1 | double | pllCfg.Ts |
| theta_e_hat / phase_error | 输出 | 电角 rad，[-π,π] | double | pllCfg.Ts |
| omega_e_hat / integral | 输出 | 电角 rad/s | double | pllCfg.Ts |
| valid / lock_count | 输出 | 0/1、样本数 | double | pllCfg.Ts |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| pllCfg：Ts、Kp、Ki、Kaw、OmegaMax、Theta0、Omega0 | s、1/s、1/s²、rad/s、rad | [angle_tracking_parameters.m](parameter/angle_tracking_parameters.m) |
| MinMagnitude、LockError、LockSamples | 幅值单位、rad、样本 | 同上 |

所有配置、状态和 Scope 顺序见 [parameter/README.md](parameter/README.md)。修改 NaturalFrequency/Damping 时须重新计算 Kp/Ki/Kaw；不会自动在线整定。

双击PLL库块，在PLL configuration中填写调用方的配置表达式，默认pllCfg；同一模型可分别填写pllA、pllB。每个实例的Mask将该表达式解析为内部pllCfg，各实例状态独立保存；无需复制库文件。两实例操作见[教程](build_process/USAGE.md)。

## 验证

入口：[run_angle_tracking_validation.m](waveform_analysis/run_angle_tracking_validation.m)。结果：`results.mat`（运行验证后生成）、[metrics.json](waveform_analysis/metrics.json)。

R2026b Update 1 下原12项MIL和新增3项实例隔离测试全部通过，结构检查为healthy。[实例分析](waveform_analysis/INSTANCES.md)保存不同增益/初值、交换配置和单实例修改的解析对照；新增Mask后另重跑SMO14项通过。覆盖正反转、包角、加速、速度变化、噪声、幅值丢失、复位、禁能、限速和初始误差；未进行single/SIL、C2000构建或板测。
