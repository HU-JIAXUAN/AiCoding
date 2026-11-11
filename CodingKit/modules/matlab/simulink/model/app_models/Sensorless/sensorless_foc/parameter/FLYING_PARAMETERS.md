# FlyingFluxFOC 参数、状态与通道

模型：[FlyingFluxFOC.slx](../src/FlyingFluxFOC.slx)。本页只对应带速捕获App；原SMO/EEMF/Flux启动App的参数和Scope继续见[README](README.md)。

## 配置与重新加载

可执行入口为[flying_foc_parameters.m](flying_foc_parameters.m)，返回`p`。修改后由[refresh_flying_foc_parameters.m](refresh_flying_foc_parameters.m)校验并重算派生向量。默认值属于本仿真实例。

| 配置 | 默认值 / 单位 | 含义 |
|---|---|---|
| bridgeCfg.Rs / Ld / Lq / Flux | 0.5 Ω / 1 mH / 1 mH / 0.035 Wb | SPMSM；本观测器要求Ld=Lq |
| bridgeCfg.PolePairs / J / B | 4 / 5e-4 kg·m² / 1e-4 N·m·s/rad | 极对数、惯量、摩擦 |
| bridgeCfg.Id0 / Iq0 / Speed0 / Position0 | 0 A / 0 A / 80机械rad/s / 0.1机械rad | 物理初值；只用于Plant，不输入观测器 |
| bridgeCfg.Ts / Vdc / DiodeVf / DiodeRon | 5 μs / 48 V / 0.7 V / 0.01 Ω | 物理步长、刚性可吸能母线、PWL二极管 |
| bridgeCfg.MechanicalEnabled | 1 | 自由机械动态；其余物理数值边界见[桥参数](../../../../lib/永磁同步电机/parameter/BRIDGE_PARAMETERS.md) |
| currentCfg.Ts / Kaw | 50 μs / 20000 s⁻¹ | 电流/估算/监督周期；预充跟踪要求Kaw=1/Ts |
| currentCfg.Kpd / Kpq / Kid / Kiq | π / π V/A；500π / 500π V/(A·s) | `current_parameters`以500 Hz生成；可直接修改增益 |
| inverterCfg.MinDuty / LinearLimit | 0.02 / 约26.6043 V | SVPWM占空比余量与dq电压圆；母线改变后LinearLimit自动刷新 |
| fluxCfg / pllCfg | 继承共用库M默认值 | Rs/L/Flux/p/Ts按本机重算；泄漏10 Hz、直流去除3 Hz、频率滤波5 Hz，完整字段见[Flux参数](../../../../lib/观测器/磁链/parameter/README.md)及[PLL参数](../../../../lib/相位跟踪/parameter/README.md) |
| flyingCfg.MinOmega / MaxResidual | 140电角rad/s / 5 A-equivalent | 估算速度与磁链幅值残差资格 |
| flyingCfg.CaptureTime / PrechargeTime | 25 ms / 10 ms | 连续资格和PWM仍关断的PI准备阶段 |
| flyingCfg.LossTime / Timeout | 1 ms / 0.6 s | 失效累计与未捕获超时 |
| flyingCfg.CaptureCurrentMax / CaptureVoltageMax | 0.5 A / 约23.9439 V | 允许接通的dq电流模和端电压模；后者独立设置，改变Vdc时需同步调整，不得高于LinearLimit |
| flyingCfg.CurrentTrip / CurrentMax | 12 A / 8 A | dq电流模退出阈值 / q电流参考幅值限制；不是硬件保护额定值 |
| flyingCfg.SpeedKp / SpeedKi / SpeedKaw | 0.08 A/(rad/s) / 0.8 A/rad / 20 s⁻¹ | 每50 μs更新的机械速度PI及已分配q参考跟踪 |
| flyingCfg.CurrentReferenceSlew | 100 A/s | d/q参考分别限斜率 |
| experimentCfg.Duration / SpeedReference | 1 s / 100机械rad/s | 总时长与恒定目标；负值可验证反转捕获 |
| experimentCfg.LoadTorque / LoadTime | 0 N·m / 0.5 s | 时间到达后施加恒定带符号负载转矩 |
| experimentCfg.Enable | 1 | 默认使能 |
| experimentCfg.ResetTime / ResetDuration | inf / 5 ms | 控制器复位事件；inf表示不发生 |
| experimentCfg.DisableTime / ReenableTime | inf / inf | 禁能区间；只关PWM及控制状态，不复位Plant |
| experimentCfg.ObserverOffTime / ObserverOnTime | inf / inf | 观测器失效注入区间 |

`bridgeCfg.Vector/State0`、`fluxCfg`滤波系数、`flyingCfg.Vector`及整数拍数是派生值。修改物理参数后执行刷新；若需要按新电感重新设计电流增益，重新调用`current_parameters(p.bridgeCfg)`并恢复Ts与Kaw。不要只改`BandwidthHz`而保留旧Kp/Ki。

```matlab
p = flying_foc_parameters();
p.bridgeCfg.Speed0 = -80;
p.experimentCfg.SpeedReference = -100;
p = refresh_flying_foc_parameters(p);
out = run_flying_foc_case(p); % SimulationInput单次覆盖，不改SLX默认值
```

修改M默认值并希望直接点Run：先加载模型，再执行`initialize_flying_foc('FlyingFluxFOC')`。运行入口和读取日志见[运行方法](../build_process/FLYING_USAGE.md)。

## 输入、采样与输出

`flyingStim`是50 μs的Structure With Time，5列依次为：机械速度目标(rad/s)、负载(N·m)、enable、reset、observerEnable；最后三列用兼容逻辑的double。模型没有方向、真实角度或真实转速的控制输入。`Speed0/Position0`属于Plant初值，不是测量信号。

Plant在5 μs边界输出`i[k]`；电流经`CurrentSample`以50 μs取得。Plant电压描述刚要求解的5 μs区间，先经过`VoltageCompleted`一个物理拍，再采样，因此送入估算器的是刚完成区间的等效电压，名义中点年龄2.5 μs。`AgeAlign`按估算ω乘该年龄补偿控制角和用于PI准备的电压。它是局部匀速近似，不把区间电压当瞬时ADC，也没有补偿硬件ADC、开关纹波或器件延迟。Flux仍按自身50 μs离散模型使用采样电压更新下一估计状态。

日志均50 μs。直接点Run时Simulink保存列向量信号为`宽度×1×时间`；`run_flying_foc_case`将其整理为`时间×通道`并保留时间向量。三份日志为：`plant_trace`34列，`observer_trace`19列，`controller_trace`29列。实际源及宽度由[flying_foc_channels.m](flying_foc_channels.m)维护。

## 过程状态

`Controller/SequenceState`初值8个0，依次为`mode、qualificationN、stageN、lossN、fault、speedI、referenceD、referenceQ`。前5项无量纲/拍数，后三项A。`Sequence`的12维输出依次为：`idRef、iqRef、bridgeMode、piEnable、piReset、precharge、mode、fault、qualificationN、lossN、speedI、iqTarget`。电流/积分单位A，开关与计数无量纲。

模式：0关；1观察资格；2关断中准备PI；3闭环运行；5锁定退出。故障码：0无；1超时/低可观测性；2目标方向不符或目标为0；3电压余量不足；4捕获电流过大；5失锁；6超过dq电流模阈值；7非有限输入或非法内部模式。故障保持，reset或disable清控制状态；Plant物理状态始终由自己的Unit Delay连续推进。

## 日志列号

| 日志 | 列号及顺序 |
|---|---|
| plant_trace | 1–2 iαβ(A)，3–5 iabc(A)，6–8 uabc(V)，9–10 uαβ(V)，11 ωm(rad/s)，12 θe(rad)，13 Te(N·m)，14 Idc(A)，15–17二极管状态，18 Wmag(J)，19 Wkin(J)，20桥损耗(W)，21方程残差(V)，22–24下一物理拍iabc诊断(A)，25中性点(V)，26–28极点电压(V)，29桥模式，30速度目标(rad/s)，31负载(N·m)，32enable，33reset，34observerEnable |
| observer_trace | 1–2采样iαβ(A)，3–4已完成区间采样uαβ(V)，5 θraw(rad)，6 ωe(rad/s)，7 valid，8–9转子磁链(Wb)，10–11定子磁链(Wb)，12磁链模(Wb)，13估算转矩(N·m)，14测量相位(rad)，15PLL相误差(rad)，16等效残差(A-equivalent)，17滤波ωe(rad/s)，18补偿ready，19控制θ(rad) |
| controller_trace | 1–12 Sequence输出，13–14测量idq(A)，15–16电流误差(A)，17–18 PI请求(V)，19–20限幅电压(V)，21–22当前积分基值(V)，23–24保存积分状态(V)，25–26 PI残差(V)，27–29占空比 |

Plant的22–24列是下一物理拍诊断，未接入控制；真实角/速度也仅接日志和Scope。二极管状态仅在桥模式0时按下管+1、上管−1、断开0解释。刚性母线电流为负表示能量流入母线。

## Scope通道

| Scope位置 | 实际通道顺序 | 来源与观察内容 |
|---|---|---|
| 根 / AngleScope | 1真实θe，2θraw，3θused；rad | Plant.y6 / Estimator.y1 / AgeAlign.y1；仅对照 |
| 根 / SpeedScope | 1真实ωm，2估算ωm，3目标；机械rad/s | Plant.y5 / EstimateMechanical / Inputs.y1 |
| 根 / OffCurrentScope | 1–3 iabc，4 Idc；A | Plant.y2 / Plant.y8；关断后仍可能续流或整流 |
| 根 / ModeScope | 1桥模式，2valid，3enable，4reset；无量纲 | Controller.y2 / Estimator.y3 / Inputs.y3、y4 |
| Controller / CurrentScope | 1–2参考idq，3–4测量idq；A | ReferenceDQ / CurrentDQ；都在估算控制坐标中 |
| Controller / VoltageScope | 1–2 PI请求，3–4限幅请求，5–6准备阶段跟踪的端电压dq；V | CurrentPI / VoltageLimit / VoltageDQ |
| Controller / SequenceScope | 1–12 Sequence输出，顺序同上 | Sequence.y2；区分准备与PWM运行，查看故障码 |

每个Scope只有一个向量输入，以上序号是向量元素顺序。没有另设真实dq电流Scope。
