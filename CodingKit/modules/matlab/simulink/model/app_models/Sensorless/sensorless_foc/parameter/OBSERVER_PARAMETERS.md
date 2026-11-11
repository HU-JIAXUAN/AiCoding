# EEMF / 磁链 App 参数和 Scope

入口为[observer_foc_parameters.m](observer_foc_parameters.m)，返回完整的`p`结构体。共同电机、速度环、电流环、启动、执行链和六列工况沿用[sensorless_foc_parameters.m](sensorless_foc_parameters.m)。本页只列两份新App的差异；共同信号及Scope见[参数README](README.md)。

| 配置 | 默认值 | 单位 / 作用 |
|---|---|---|
| currentCfg.Ts / experimentCfg.Step / Duration | 50e-6 / 5e-6 / 2 | s；控制拍、对象步长、运行时长 |
| emfCfg.Rs / Ld / Lq / Flux / PolePairs | 0.5 / .001 / .001 / .035 / 4 | Ω / H / H / Wb / 1；本App共同SPMSM基线，EEMF库还可单独验证凸极电机 |
| emfCfg.BandwidthHz | 300 | Hz；电流/反电势全阶观测极点，打包为2πf |
| emfCfg.MinEmf / MinOmega / MaxResidual | 1 / 30 / 1.5 | V / 电角rad/s / A；幅值、方向速度及电流残差资格 |
| fluxCfg.Rs / L / Flux / PolePairs | .5 / .001 / .035 / 4 | Ω / H / Wb / 1；本磁链库仅用于SPMSM |
| fluxCfg.LeakEnable / LeakHz | 1 / 10 | 逻辑 / Hz；泄漏积分抑制直流漂移 |
| fluxCfg.DcEnable / DcHz | 1 / 3 | 逻辑 / Hz；去除积分输出直流分量 |
| fluxCfg.FrequencyHz | 5 | Hz；用于补偿的历史估速低通 |
| fluxCfg.MinCompOmega / FullCompOmega / MaxCompGain | 20 / 100 / 4 | 电角rad/s / 电角rad/s / 1；补偿渐入与增益上限 |
| fluxCfg.MinFlux / MaxFlux | .015 / .0525 | Wb；最小PLL幅值、最大转子磁链幅值 |
| fluxCfg.MinOmega / MaxResidual | 120 / 5 | 电角rad/s / A-equivalent；后者是磁链幅值误差除以L |
| pllCfg.MinMagnitude | EEMF:1；Flux:.015 | 分别为V / Wb，与各观测器幅值资格同步 |
| pllCfg.Ts / Kp / Ki / OmegaMax | 50e-6 / 约355.38 / 约63165 / 1500 | s / 1/s / 1/s² / 电角rad/s；由公共PLL参数函数生成 |
| pllCfg.LockError / LockSamples | .12 / 100 | rad / 拍；连续相位资格 |
| handoverCfg.MaxResidual | EEMF:1.5；Flux:5 | A / A-equivalent；Flux与fluxCfg.MaxResidual同步，默认5mWb幅值误差 |
| handoverCfg.AllowFlying | 0 | 此组App不实施带速捕获 |

`refresh_flux_parameters`重算LeakA、LeakB、DcA和FrequencyA，运行器会调用它；启动、接管的派生拍数也会刷新。更改PLL自然频率时应在PLL参数函数中重算Kp、Ki；不要只修改已经返回的NaturalFrequency字段。更改磁链质量阈值时，同时设置`p.fluxCfg.MaxResidual`和`p.handoverCfg.MaxResidual`，二者单位均为A-equivalent。

## 输入、状态和输出

`Observer`外部仍为5入4出：三相作用电压(V)、采样αβ电流(A)、enable、reset、direction → θ̂(电角rad)、ω̂(电角rad/s)、valid、residual_norm。Flux内核不需要direction，该输入仅记录并用于公共启动控制。两份App的真实角度只进入Plant/VoltageStage的物理坐标换算与离线误差计算。

EEMF状态为`[i_hat_alpha;i_hat_beta;e_hat_alpha;e_hat_beta]`和公共PLL状态；停用、复位或方向变化清除观测状态。Flux状态为泄漏磁链αβ、直流磁链αβ、历史滤波估速和PLL状态；停用或复位清除状态。初值均为0。

四组日志时间完全一致，均为50μs。Plant为13列、Controller46列、Actuation26列；EEMF Observer为20列，Flux Observer为22列。真实列号由[observer_foc_channels.m](observer_foc_channels.m)和返回结果的`r.observer.columns`给出。两者前3列均为θ̂、ω̂、valid，之后分别记录真实的反电势/电流诊断或磁链诊断。Flux没有估计电流输出。

## 新 App 的 Observer Scope

每个Scope只有一个向量输入，下表编号就是向量中的元素顺序。其余Plant、Controller Scope保持[原参数页](README.md#scope-通道)的顺序。

| App / Scope | 通道顺序及单位 | 实际源端口 |
|---|---|---|
| 两者 / EstimateAngleScope | 1 θ̂，电角rad | Estimator.y1 |
| 两者 / EstimateSpeedScope | 1 ω̂，电角rad/s；除以PolePairs才是机械速度 | Estimator.y2 |
| EEMF / EmfScope | 1 Eα、2 Eβ、3 幅值，V | Estimator.y4/y5/y11 |
| EEMF / ResidualScope | 1 rα、2 rβ、3 二范数，A | Estimator.y8/y9，ResidualNorm.y1 |
| Flux / FluxScope | 1 ψrα、2 ψrβ、3 幅值，Wb | Estimator.y4/y5/y8 |
| Flux / QualityScope | 1 等效残差(A-equivalent)、2 历史估速(电角rad/s)、3 补偿就绪(0/1) | Estimator.y12/y13/y14 |
| 两者 / ValidityScope | 1 valid、2 enable、3 reset，0/1 | Estimator.y3，enable.y1，reset.y1 |

[运行和修改参数](../build_process/OBSERVER_USAGE.md) · [公式推导](../docs/公式推导.md)
