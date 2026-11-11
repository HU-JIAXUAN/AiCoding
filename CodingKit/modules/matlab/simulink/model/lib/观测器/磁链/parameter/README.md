# 参数、输入输出与Scope

## 配置参数

默认值在[flux_parameters.m](flux_parameters.m)，派生系数由[refresh_flux_parameters.m](refresh_flux_parameters.m)刷新；默认轨迹在[flux_test_parameters.m](flux_test_parameters.m)。修改M文件后停止仿真，执行`initialize_flux_test('FluxObserverTest')`重新加载；单次覆盖见[运行方法](../build_process/USAGE.md)。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts / Rs / L / Flux / PolePairs | 50e-6 / 0.5 / 0.001 / 0.035 / 4 | s / Ω / H / Wb / 1 | SPMSM对象、周期及转矩换算；Ld=Lq=L |
| LeakEnable / LeakHz | 1 / 10 | 逻辑 / Hz | 泄漏积分；关闭时为纯积分 |
| DcEnable / DcHz | 1 / 3 | 逻辑 / Hz | 去除直流分量；关闭时dc状态保持0 |
| FrequencyHz | 5 | Hz | 频率补偿使用的估算速度低通 |
| MinCompOmega / FullCompOmega | 20 / 100 | 电角rad/s | 补偿逐步启用的区间 |
| MaxCompGain | 4 | 1 | 补偿增益限制 |
| MinFlux / MaxFlux | 0.015 / 0.0525 | Wb | PLL最小幅值及外部最大幅值资格 |
| MinOmega / MaxResidual | 120 / 5 | 电角rad/s / 等效A | 有效性门限，等效残差不是电流预测创新 |
| LeakA / LeakB / DcA / FrequencyA | 由上述参数计算 | 1 / s / 1 / 1 | 离散系数；调用refresh函数生成，不手填 |
| pllCfg | 共用PLL默认值，Ts和MinMagnitude随fluxCfg覆盖 | SI | [angle_tracking_parameters.m](../../../相位跟踪/parameter/angle_tracking_parameters.m)定义增益、锁定持续时间及限速 |
| Duration / ElectricalSpeed / InitialAngle | 1 / 200 / 0.4 | s / 电角rad/s / rad | 默认独立轨迹；初始角仅用于fixture和评估 |
| Id / Iq / Enable / Reset | -2 / 2 / 1 / 0 | A / A / 逻辑 / 逻辑 | 默认电流与开关 |

Mask的两个参数分别是fluxCfg与pllCfg结构体。测试台模型工作区另有fluxTestCfg及九列testStim；SLX中的数值从这些变量读取。

## 输入信号

| 库端口 | 名称 | 单位/类型 | 来源与用途 |
|---|---|---|---|
| 1–2 | u_alpha / u_beta | V，double | 本周期实际执行电压或重建电压，形成下一拍定子磁链 |
| 3–4 | i_alpha / i_beta | A，double | 同年龄电流，本拍减L·i及下一拍积分 |
| 5 | enable | 0/1，double兼容逻辑 | 非零且未reset才工作 |
| 6 | reset | 0/1，double兼容逻辑 | 复位优先，清状态并撤销资格 |

周期默认50 μs，无方向及真实位置/速度输入。fixture另有direction、theta_true、omega_true三列：direction不接算法，theta/omega只用于Scope/误差。九列输入顺序为uα,uβ,iα,iβ,direction,enable,reset,θtrue,ωtrue。

## 过程变量

| 名称 | 单位/初值 | 所在块与计算/用途 |
|---|---|---|
| z_alpha / z_beta | Wb / 0 | FluxStates(1:2)，泄漏积分 |
| dc_alpha / dc_beta | Wb / 0 | FluxStates(3:4)，积分输出的低通直流估计 |
| filtered | Wb | Compute内z−dc，待频率补偿的二维向量 |
| filtered_speed | 电角rad/s / 0 | FrequencyState，上一拍PLL速度的独立低通状态 |
| Craw / compensation weight | 复数无量纲 / 0到1 | Compute的逆频响补偿与低速渐入；详细公式见[STEPS.md](../build_process/STEPS.md) |
| active | 逻辑 | Active块，enable AND NOT reset |
| PLL状态 | 电角rad、rad/s、计数 | 嵌套AngleTracking/PLL；见[PLL参数](../../../相位跟踪/parameter/README.md) |
| equivalent_residual | 等效A | abs(norm(ψrotor)−Flux)/L，检查磁链幅值一致性 |

禁能/复位时磁链、转矩和质量输出置零；filtered_speed作为状态诊断可在触发当拍保留旧值，下一拍清零。计算输出与预测下一状态分离。

## 输出信号

| 库端口 | 名称 | 单位/类型 | 计算与用途 |
|---|---|---|---|
| 1 | theta_e_hat | 电角rad，double | PLL跟踪ψrotor方向，包角到±π |
| 2 | omega_e_hat | 电角rad/s，double | 带符号PLL速度，机械速度需除PolePairs |
| 3 | valid | 0/1，double | PLL、幅值、速度、残差、补偿就绪及active共同资格 |
| 4–5 | rotor_flux_alpha / rotor_flux_beta | Wb，double | 补偿后的定子磁链减L·i |
| 6–7 | stator_flux_alpha / stator_flux_beta | Wb，double | 经离散频率补偿的定子磁链 |
| 8 | flux_magnitude | Wb，double | 转子磁链向量模长 |
| 9 | torque_hat | N·m，double | 1.5·PolePairs·cross(ψrotor,i) |
| 10 | phase_measured | 电角rad，double | atan2(ψrotor_beta,ψrotor_alpha)，PLL前相位 |
| 11 | phase_error | 电角rad，double | PLL本拍包角误差 |
| 12 | equivalent_residual | 等效A，double | 磁链幅值相对配置Flux的偏差，不使用真实磁链 |
| 13 | filtered_speed | 电角rad/s，double | 补偿频率状态诊断 |
| 14 | compensation_ready | 0/1，double | 补偿权重≥0.99，且未触发补偿增益限幅 |

To Workspace变量为trace：列1–9为fixture输入，列10–23依次为以上14个库输出，列24为wrap(theta_e_hat−theta_true)。结构格式为Structure With Time，时间在trace.time，数值在trace.signals.values。统一指标窗口0.8–1.0 s。

## Scope 通道

以下为FluxObserverTest内实际已连接的七个Scope；每行按实际通道顺序填写。源`Observer.yN`指库输出端口N，`Inputs.yN`指fixture列N。

| Scope/通道 | 名称 | 来源 / trace列 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope / 1 | theta_true | Inputs.y8 / 8 | 电角rad | 仅评估的真实角度 |
| AngleScope / 2 | theta_e_hat | Observer.y1 / 10 | 电角rad | 估计角度 |
| AngleScope / 3 | wrapped_angle_error | AngleError / 24 | 电角rad | 包角角误差 |
| SpeedScope / 1 | omega_true | Inputs.y9 / 9 | 电角rad/s | 仅评估的真实速度 |
| SpeedScope / 2 | omega_e_hat | Observer.y2 / 11 | 电角rad/s | PLL估计速度 |
| RotorFluxScope / 1 | rotor_flux_alpha | Observer.y4 / 13 | Wb | 永磁磁链α分量 |
| RotorFluxScope / 2 | rotor_flux_beta | Observer.y5 / 14 | Wb | 永磁磁链β分量 |
| RotorFluxScope / 3 | flux_magnitude | Observer.y8 / 17 | Wb | 幅值偏差/漂移 |
| StatorFluxScope / 1 | stator_flux_alpha | Observer.y6 / 15 | Wb | 补偿后定子磁链α |
| StatorFluxScope / 2 | stator_flux_beta | Observer.y7 / 16 | Wb | 补偿后定子磁链β |
| TorqueScope / 1 | torque_hat | Observer.y9 / 18 | N·m | 磁链/电流估计转矩 |
| QualityScope / 1 | valid | Observer.y3 / 12 | 0/1 | 是否达到在线资格 |
| QualityScope / 2 | equivalent_residual | Observer.y12 / 21 | 等效A | 幅值一致性；与valid同Scope，单位不同 |
| CompensationScope / 1 | filtered_speed | Observer.y13 / 22 | 电角rad/s | 用于补偿的频率状态 |
| CompensationScope / 2 | compensation_ready | Observer.y14 / 23 | 0/1 | 补偿是否进入可信区域；与速度单位不同 |

phase_measured、phase_error记录在trace但没有单独Scope通道。输入电压/电流也只在trace，不写成已有Scope。valid不读取真实角误差；关闭直流去除的偏置工况中valid仍可能为1，应结合误差与磁链波形评估。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d=L_q$ | cfg.L | H | SPMSM公共电感；原表mH乘$10^{-3}$，局部符号$\ell_{sp}$ |
| $\psi_m$ | cfg.Flux | Wb | 直接使用 |
| $P$ | cfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | AngleTracking/PLL输出1；pllCfg.Theta0给定初始状态 | 电角rad | 这里PLL的输入已构造成转子电相位 |
| $\hat\omega_r$ | AngleTracking/PLL输出2 | 电角rad/s | 机械rad/s乘P得到电角rad/s；估计机械速度为本输出除P |

### 本模块局部量

$\ell_{sp}=L_d=L_q$为SPMSM公共电感，工程L使用H；$\mathcal Q[x,y]^T=[-y,x]^T$为平面旋转算子，不使用原表转动惯量$J$表示它。$\omega_{rot}$是恒频频响分析角频率，在线补偿采用延迟估速。
