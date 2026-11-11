# 高频/饱和PMSM对象的参数与Scope

## 配置参数

入口：[pmsm_hf_parameters.m](pmsm_hf_parameters.m)、[refresh_pmsm_hf_parameters.m](refresh_pmsm_hf_parameters.m)、[hf_plant_test_parameters.m](hf_plant_test_parameters.m)。修改M文件后执行initialize_hf_plant_test；单次覆盖见[运行方法](../build_process/HF_USAGE.md)。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Rs / Ld / Lq / Flux | 0.5 / 0.001 / 0.0015 / 0.035 | Ω / H / H / Wb | 每相电阻、零d电流增量Ld、恒定Lq和永磁磁链 |
| PolePairs / J / B | 4 / 5e-4 / 1e-4 | 1 / kg·m² / N·m·s/rad | 极对数、惯量和黏性阻尼 |
| SaturationDepth / SaturationCurrent | 0.25 / 1 | 1 / A | 磁链饱和深度和d电流尺度 |
| CrossInductance | 0 | H | 对称的常量dq交叉电感M |
| MechanicalEnabled | 1 | 0/1 | 1自由机械运动；0为理想锁轴测试夹具 |
| Id0 / Iq0 / Speed0 / Position0 | 全0 | A / A / 机械rad/s / 机械rad | 四个物理状态初值 |
| Settings / InitialState | 根据上述字段生成 | 混合SI | 11项动力学参数和4项初值，不手工维护第二份数值 |
| Ts / PlantStep / Duration | 50e-6 / 2.5e-6 / 0.1 | s | 电压/输出采样、ode4积分步长和时长 |
| PulseVoltage / PulseWidth | 4 / 0.001 | V / s | 正负脉冲同幅同宽 |
| PositiveStart / NegativeStart | 0.020 / 0.065 | s | 正负脉冲起点 |
| VoltageAxis / LoadTorque | 0 / 0 | 静止αβ电角rad / N·m | 测试电压方向与有符号负载 |

电机参数为合成示意值，没有实测或有限元拟合来源。Mask参数为本实例的hfPlantCfg。测试台工作区另有hfPlantTestCfg、testStim。必须满足0≤SaturationDepth<1、正电感及Ld·(1−SaturationDepth)·Lq>CrossInductance²；锁轴初始速度为0。

## 输入信号

| 端口 | 名称 | 单位/类型 | 来源/用途 |
|---|---|---|---|
| 1–2 | u_alpha / u_beta | V / double | 实际αβ作用电压；测试台由零阶保持脉冲给出 |
| 3 | load_torque | N·m / double | 进入Te−Tl−Bω的有符号负载；与电磁转矩分开 |

库对象是连续系统，输入可由离散执行链保持。它不消费估计角度，物理θ由内部机械状态产生。测试台输入向量列1–3为uα、uβ、Tl。

## 过程变量

| 名称 | 单位/初值 | 来源与计算/用途 |
|---|---|---|
| PhysicalStates(1:4) | A、A、机械rad/s、机械rad；默认0 | 连续Integrator保存id、iq、ωm、θm |
| psi_d / psi_q | Wb | 同一非线性磁链关系产生电压平衡与转矩 |
| incremental_ld | H | ∂ψd/∂id；不是ψd/id，范围Ld·(1±SaturationDepth) |
| differential inductance | H | [incremental_ld,M;M,Lq]，对称正定 |
| balanceD / balanceQ | V | 去掉电阻压降并计入旋转磁链项后的电感电压 |
| derivative | A/s、A/s、机械rad/s²、机械rad/s | 2×2增量电感方程和机械平衡的导数 |
| SampledSignals | 十维double | 测试台50 μs零阶保持采样，用于Scope/trace；不改变Plant积分状态 |

## 输出信号

| 端口 | 名称 | 单位/类型 | 用途 / trace列 |
|---|---|---|---|
| 1–2 | i_alpha / i_beta | A / double | 电流采样/观测器输入；列4–5 |
| 3 | theta_e | 电角rad / double | 内部物理位置包角到±π，仅供评估；列6 |
| 4 | omega_e | 电角rad/s / double | p·ωm，仅供评估；列7 |
| 5 | torque | N·m / double | 1.5·p·(ψd·iq−ψq·id)；列8 |
| 6–7 | id / iq | A / double | 物理dq电流诊断；列9–10 |
| 8 | incremental_ld | H / double | 增量Ld诊断；列11 |
| 9–10 | psi_d / psi_q | Wb / double | 非线性磁链诊断；列12–13 |

trace列1–3为实际输入，4–13为上述十个输出。Structure With Time格式：时间在trace.time，数值在trace.signals.values。theta_e、omega_e、id/iq等物理诊断不应接入无位置观测器代替测量。

## Scope 通道

测试台六组Scope均接50 μs采样后的Outputs；`Outputs.yN`对应Plant输出端口N。

| Scope/通道 | 名称 | 来源 / trace列 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| HfCurrents / 1 | i_alpha | Outputs.y1 / 4 | A / double | 静止α轴测量电流 |
| HfCurrents / 2 | i_beta | Outputs.y2 / 5 | A / double | 静止β轴测量电流 |
| HfCurrents / 3 | id | Outputs.y6 / 9 | A / double | 物理d轴脉冲响应 |
| HfCurrents / 4 | iq | Outputs.y7 / 10 | A / double | 物理q轴及转矩相关响应 |
| HfAngle / 1 | theta_e | Outputs.y3 / 6 | 电角rad / double | 实际位移与包角 |
| HfSpeed / 1 | omega_e | Outputs.y4 / 7 | 电角rad/s / double | 自由转动或锁轴 |
| HfTorque / 1 | torque | Outputs.y5 / 8 | N·m / double | 注入产生的电磁转矩 |
| HfFlux / 1 | psi_d | Outputs.y9 / 12 | Wb / double | 磁极偏置与饱和磁链 |
| HfFlux / 2 | psi_q | Outputs.y10 / 13 | Wb / double | q轴和交叉磁链 |
| HfInductance / 1 | incremental_ld | Outputs.y8 / 11 | H / double | 正负电流导致的增量电感变化 |

输入电压和负载只在trace记录，不列为已有Scope通道。结果图另外按需要绘制这些输入。

[模块参数入口](README.md) · [搭建公式](../build_process/HF_BUILD.md) · [模块入口](../README.md)
