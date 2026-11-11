# 参数与信号

## 配置参数

[mit_joint_parameters.m](mit_joint_parameters.m) 组合现有 FOC 参数。保存参数文件后重新打开模型，或调用 `initialize_mit_joint_control('MitJointControl')` 重载模型工作区。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `UseMitMode` | true | 1 | 本次仿真选择 MIT Mode，false 选择现有位置／速度控制 |
| `GearRatio` | 6 | 1 | 电机转速与关节转速之比 |
| `Kt` | 0.21 | N·m/A | 现有 PMSM 电机轴转矩常数 |
| `CurrentLimit` | 8 | A | 对称 q 轴峰值电流限幅 |
| `BusVoltageMax` | 60 | V | MIT 支路电流置零阈值，配合现有 48 V 仿真母线 |
| `FeedforwardMemory` | 0.9 | 1 | Katz 固件离散前馈滤波系数 |
| `Kp`、`Kd` | 2、0.12 | N·m/rad、N·m·s/rad | 关节刚度和阻尼 |
| `PositionReference`、`VelocityReference` | 0.2、0 | rad、rad/s | 关节侧目标 |
| `FeedforwardTorque`、`LoadTorque` | 0、0.18 | N·m | 关节侧前馈和反向载荷 |
| `experimentCfg.CommandTime`、`LoadTime`、`Duration` | 0.05、0.35、1.2 | s | 命令、负载阶跃时间和仿真时长 |

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $P$ | `pmsmCfg.PolePairs` | 1 | 无 |
| $\psi_m$ | `pmsmCfg.Flux` | Wb | 无 |
| $\omega_m$ | `Mechanical` 的 `omega_m` 输出 | rad/s | 除以减速比得到关节速度 |
| $T_{m\_BLAC}$ | `Electrical` 的 `torque` 输出 | N·m | 乘以减速比得到关节侧估算转矩 |
| $T_L$ | `LoadTorque` 的电机侧输出 | N·m | 关节载荷除以减速比 |
| $V_{dc}$ | `inverterCfg.Vdc` | V | 无 |

## 输入信号

| 名称 | 单位 | 类型 | 来源与用途 |
|---|---|---|---|
| `q_ref, dq_ref, kp, kd, tau_ff` | 见配置 | double | 模型的五参数给定 |
| `q, dq` | rad、rad/s | double | 电机多圈位置和速度除以减速比 |
| `active, bus_voltage` | 1、V | boolean、double | 模式、使能、复位及现有母线配置 |

## 过程变量

| 名称 | 单位 | 状态初值 | 所在块与用途 |
|---|---|---|---|
| `tau_ff_filtered` | N·m | 0 | `FeedforwardState` 实现前馈滤波 |
| `tau_request` | N·m | 代数 | `TotalTorque` 的关节侧限流前指令 |
| `JointTorqueEstimate` | N·m | 代数 | PMSM 电磁转矩乘减速比 |

## 输出信号

| 名称 | 单位 | 类型 | 来源与用途 |
|---|---|---|---|
| `iq_ref` | A | double | MIT 支路的限幅和过压门控输出 |
| `SelectQCurrent, SelectDCurrent` | A | double | 共用 FOC 实际采用的 q、d 电流参考 |
| `mitTrace` | 逐列 SI | double[13] | `SaveMITTrace` 保存的关节记录 |

## Scope 通道

现有 [MotorExperiment Scope](../../Sensor/experiment/parameter/README.md) 保持电机侧单位。关节侧 `mitTrace.signals.values` 按下表记录。

| 列 | 信号 | 单位 |
|---|---|---|
| 1–4 | `q_ref, dq_ref, q, dq` | rad、rad/s |
| 5–7 | `tau_ff, tau_ff_filtered, tau_request` | N·m |
| 8–10 | `iq_ref`（MIT）、`iq_ref`（选中）、`iq`（反馈） | A |
| 11–12 | `JointTorqueEstimate, JointLoadTorque` | N·m |
| 13 | `id_ref`（选中） | A |
