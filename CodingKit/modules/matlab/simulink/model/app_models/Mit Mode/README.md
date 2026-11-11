# 单关节 MIT Mode

## 用途

复刻 Katz 关节驱动器的五参数控制。与现有位置 P／速度 PI 支路并列，在 `CurrentStage` 入口选择一组 dq 电流参考，复用 `MotorExperiment` 的电流 PI、前馈、反馈时序、平均逆变器和 PMSM 库链接。

## 文件

| 路径 | 状态 |
|---|---|
| [src/MitJointControl.slx](src/MitJointControl.slx) | 已创建 |
| [parameter](parameter/README.md) | 已创建 |
| [build_process](build_process/README.md) | 已创建 |
| [waveform_analysis](waveform_analysis/README.md) | 已创建 |
| [ref](ref/README.md) | 已创建 |
| [docs](docs/README.md) | 已创建 |

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| `q_ref, dq_ref` | MIT 支路给定 | rad、rad/s，关节侧 | double | 外部给定 1 ms，MIT 计算 100 µs |
| `kp, kd, tau_ff` | MIT 支路给定 | N·m/rad、N·m·s/rad、N·m | double | MIT 计算 100 µs |
| `q, dq` | MIT 支路反馈 | rad、rad/s，关节侧 | double | 100 µs |
| `active, bus_voltage` | MIT 支路使能、母线电压 | 1、V | boolean、double | 100 µs |
| `iq_ref, tau_request, tau_ff_filtered` | MIT 支路输出 | A、N·m、N·m | double | 100 µs |
| `mitTrace` | 仿真记录 | 见参数页 | double[13] | 100 µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| `mitCfg` | 见参数页 | [mit_joint_parameters.m](parameter/mit_joint_parameters.m) |
| `experimentCfg`、`pmsmCfg`、`motionCfg`、`currentCfg` 等 | 见现有应用 | [experiment_app_parameters.m](../Sensor/experiment/parameter/experiment_app_parameters.m) |

## 验证

打开模型即可运行。默认使用 MIT Mode。将 `mitCfg.UseMitMode` 设为 `false` 并重新加载参数后，可用相同对象运行原外环。此时 `experimentCfg.Mode=2` 选位置模式，`Mode=1` 选速度模式。

[验证入口](waveform_analysis/run_mit_joint_validation.m)覆盖五参数公式、前馈递推、纯转矩、刚度、阻尼、正负限流、母线过压、复位和原位置／速度支路的一致性。结果见[仿真记录](waveform_analysis/README.md)。
