# HFI参数、信号和Scope

## 配置参数

本页记录HFIAxis；默认值在本目录M文件定义，载入模型工作区，库Mask只引用结构体。运行与重载见[USAGE](../build_process/USAGE.md)。SaliencyProbe的配置、输入/过程/输出及7组Scope见[PROBE_PARAMETERS.md](PROBE_PARAMETERS.md)；双脉冲极性块见[POLARITY_PARAMETERS.md](POLARITY_PARAMETERS.md)。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| Ts | 50e−6 | s | 控制/采样周期；[hfi_parameters.m](hfi_parameters.m) |
| InjectionVoltage | 5 | V | 注入请求幅值，方波频率1/(2Ts)=10 kHz；同上 |
| Ld / Lq / CrossInductance | .001 / .0015 / 0 | H | 观测器名义增量电感；不是物理电机自动辨识值；同上 |
| InitialAxis | 0 | 电角rad | 初始轴线分支；同上 |
| MaxOmega | 80 | 电角rad/s | 轴线速度资格上限；同上 |
| MinVoltageStep | 1 | V | 两段实际电压差投影下限；同上 |
| MaxCrossFraction | .2 | 1 | 横向电压差/轴向差最大比值；同上 |
| MinResponse / MaxResponse | .01 / .15 | A | 解调凸极响应门限；同上 |
| MinInjectionScale | .1 | 1 | 两个历史区间均需满足的注入比例；同上 |
| InverseAverage | 833.333… | 1/H | (Ld+Lq)/(2(LdLq−M²))；[refresh_hfi_parameters.m](refresh_hfi_parameters.m)推导 |
| CrossPhase | 0 | rad | atan2(−2M,Lq−Ld)，已知交叉电感补偿；同上 |
| DemodBandwidth / DemodA | 300 / exp(−2π·300·Ts) | Hz / 1 | 双角静止向量一阶低通及离散极点；hfi_parameters/refresh生成 |
| DemodFilterEnabled | 1 | 0/1 | 关闭时DemodA=0，保留未滤波对照；同上 |
| UseMeasuredInverseAverage | 0 | 0/1 | 1时使用u8实测均值，非有限或非正值拒绝解调；0时忽略u8 |
| AxisInitialState / DemodSettings / TrackSettings | 2 / 11 / 3元素 | 混合 | 由refresh生成；修改基础字段后必须refresh，不手改打包向量 |
| PLL NaturalFrequency / Damping | 30 / .707 | Hz / 1 | 双角跟踪器；[hfi_pll_parameters.m](hfi_pll_parameters.m) |
| PLL Kp / Ki / Kaw | 266.53… / 35530.58… / 376.99… | 1/s / 1/s² / 1/s | 由带宽/阻尼计算；同上 |
| PLL OmegaMax / MinMagnitude | 160 / .01 | 双电角rad/s / A | 速度为2倍，幅值仍为A；同上 |
| PLL LockError / LockSamples | .12 / 100 | 双电角rad / 拍 | 5 ms连续锁定；同上 |
| PLL Theta0 / Omega0 | wrap(2InitialAxis) / 0 | 双电角rad / rad/s | 双角初值；同上 |
| Duration / Ts / PlantStep | .25 / 50e−6 / 2.5e−6 | s | 测试时长、激励表周期、ode4步长；[hfi_test_parameters.m](hfi_test_parameters.m) |
| InitialElectricalAngle | .7 | 电角rad | 仅初始化Plant和评估；同上 |
| InjectionScale / Enable / Reset / LoadTorque | 1 / 1 / 0 / 0 | 1 / 逻辑 / 逻辑 / N·m | 测试输入默认值；同上 |
| MeasurementNoise / NoiseSeed | 0 / 42 | A RMS / 整数 | 各相独立高斯噪声；同上 |
| CurrentOffset | [0;0;0] | A | a/b/c三相ADC偏置；同上 |
| CurrentResolution / CurrentRange | 0 / 8 | A | 0关闭量化；ADC先夹到±8 A再取整；同上 |
| CurrentDelay / VoltageAlignmentDelay / ExecutionDelay | 0 / 0 / 0 | 0或1拍 | 电流测量、观测器电压年龄、实际执行延迟；同上 |
| ActuationGain | 1 | 1 | 实际电压/请求电压比；同上 |
| ExternalInverseAverage | 0 | 1/H | 独立轴线测试台u8默认值；实测模式需给出有效值 |
| SaturationDepth / CrossInductance / MechanicalEnabled | 0 / 0 / 1 | 1 / H / 逻辑 | 物理夹具；0机械标志为显式理想锁轴，1正常J/B自由运动；同上 |
| Rs / Ld / Lq / Flux / PolePairs / J / B | .5 / .001 / .0015 / .035 / 4 / 5e−4 / 1e−4 | SI | [hfi_plant_parameters.m](hfi_plant_parameters.m)组合[pmsm_hf_parameters](../../../永磁同步电机/parameter/pmsm_hf_parameters.m)，不改共用默认值 |

DemodSettings顺序为`Ts,Vh,InverseAverage,CrossPhase,MinVoltageStep,MaxCrossFraction,MinResponse,MaxResponse,MinInjectionScale,DemodA,UseMeasuredInverseAverage`。Vh保留为配置记录，实际幅值判定使用测得电压差；TrackSettings顺序为`InitialAxis,InitialTrackerPhase,MaxOmega`。

## 输入信号

| 名称/端口 | 单位 | 类型/来源 | 计算或用途 |
|---|---|---|---|
| u_alpha / u_beta，u1–u2 | V | double；实际执行电压或重建值 | u[k]对应当前[kTs,(k+1)Ts)区间，当前解调取内部历史u[k−1],u[k−2] |
| i_alpha / i_beta，u3–u4 | A | double；电流采样 | i[k]结束u[k−1]区间；不可用带有额外未知延迟的电流直接替换 |
| injection_scale，u5 | 1 | double，限0–1 | 请求比例，不等于实际电压比例 |
| enable / reset，u6–u7 | 逻辑 | double兼容 | reset优先；禁能/复位时注入为0并复位PLL/轴线 |
| inverse_average_external，u8 | 1/H | double；独立探针快照或调用者 | UseMeasuredInverseAverage=1时替代名义平均逆电感；不自动授予凸极资格 |

测试台`testStim`七列为load[N·m],scale[1],enable[逻辑],reset[逻辑],noise_a/b/c[A]。Plant真实θ、ω仅进入记录/误差Scope。

## 过程变量

| 名称 | 单位/初值 | 所在块/来源 | 用途 |
|---|---|---|---|
| VoltageOld/Older | V；[0;0] | 两级UnitDelay | 两个实际执行区间 |
| CurrentOld/Older | A；[0;0] | 两级UnitDelay | 第二电流差分 |
| AxisOld / AxisStates | rad；InitialAxis及双角初值 | UnitDelay | 前次注入轴、连续轴线展开 |
| DemodFilter | 1/H；[0;0] | UnitDelay + Demodulate | 双角静止向量低通；禁能/复位/无效历史时清零；不直接滤包角 |
| ScaleOld/Older | 1；0 | 两级UnitDelay | 恢复注入后两拍建立历史 |
| Active | 逻辑 | enable && !reset | 复位优先和激励门控 |
| CarrierState | ±1；+1 | UnitDelay + Gain(-1) | 2Ts周期方波，禁能回+1 |
| responseDQ | 1/H | Demodulate | 电流差分对电压差归一化后的轴向/正交响应 |
| phase_double | 双电角rad | Demodulate | 2轴角的相位测量，补偿已知交叉电感 |
| inverse_average_used | 1/H；0 | Demodulate | 完成历史和实际电压检查后采用的均值；未进入有效解调路径时为0 |
| PLL theta/omega/error | 双电角rad / rad/s | AngleTracking/PLL | 双角PLL；普通电角速度需除2 |
| PhaseADC | A | 三相偏置→噪声→限幅→量化 | 仅测试夹具，不是板卡已标定ADC模型 |

`axis_valid`依赖名义电感及幅值/PLL门限。圆转子平均电感设错也可能通过资格，参见反例；它既不是独立凸极性证明，也不是完整位置资格。

## 输出信号

| 名称/端口 | 单位 | 来源/用途 |
|---|---|---|
| injection_alpha/beta，y1–y2 | V | 当前估计轴上的方波请求，尚需App限压/调制 |
| theta_axis，y3 | 电角rad | 连续分支包角到±π；仍有π歧义 |
| omega_axis，y4 | 电角rad/s | 双角PLL速度/2 |
| axis_valid，y5 | 0/1 | PLL/响应/速度资格；不是极性资格 |
| phase_double，y6 | 双电角rad | 双角相位测量 |
| response_magnitude，y7 | A | 凸极响应幅值，拒绝资格时对PLL送0 |
| response_d/q，y8–y9 | 1/H | 归一化响应，不是dq电流 |
| voltage_step，y10 | V | 前两段实际电压差在上次注入轴的投影 |
| response_quality，y11 | 0/1 | 电压/横向变化/幅值/历史资格 |
| carrier，y12 | ±1 | 当前方波状态；禁能请求仍为0 |
| phase_error_double，y13 | 双电角rad | PLL鉴相误差 |
| lock_count，y14 | 拍 | PLL连续锁定计数 |
| inverse_average_used，y15 | 1/H | 实际参与去除各向同性分量的均值，便于核对校准接入 |

## Scope 通道

每个Scope一个向量输入；下面按向量中实际顺序登记。`trace`列与Scope通道不是同一个编号。

| Scope | 通道 | 名称 | 来源 | 单位/类型 | 观察内容 / trace列 |
|---|---|---|---|---|---|
| AxisScope | 1 | theta_true | Physical.y3 | 电角rad | 仅评估 / 7 |
| AxisScope | 2 | theta_axis | Observer.y3 | 电角rad | 连续轴线分支 / 14 |
| AxisScope | 3 | error_mod_pi | AxisError | 电角rad | .5wrap(2Δθ) / 26 |
| AxisScope | 4 | full_error | FullError | 电角rad | wrap(Δθ)，显示极性歧义 / 27 |
| SpeedScope | 1 | omega_true | Physical.y4 | 电角rad/s | 物理速度 / 8 |
| SpeedScope | 2 | omega_axis | Observer.y4 | 电角rad/s | 估计速度 / 15 |
| QualityScope | 1 | axis_valid | Observer.y5 | 0/1 | 轴线资格 / 16 |
| QualityScope | 2 | response_quality | Observer.y11 | 0/1 | 解调资格 / 22 |
| QualityScope | 3 | response_magnitude | Observer.y7 | A | 有效响应 / 18 |
| QualityScope | 4 | lock_count | Observer.y14 | 拍 | 持续锁定 / 25 |
| VoltageScope | 1,2 | u_actual_alpha,beta | ActualVoltage.y1,y2 | V | 实际执行 / 1,2 |
| VoltageScope | 3,4 | u_request_alpha,beta | Observer.y1,y2 | V | 注入请求 / 12,13 |
| CurrentScope | 1,2 | i_measured_alpha,beta | ObservedCurrent.y1,y2 | A | 送观测器 / 3,4 |
| CurrentScope | 3,4 | id,iq | Physical.y6,y7 | A | Plant真实dq，仅诊断 / 10,11 |
| ResponseScope | 1,2 | response_d,q | Observer.y8,y9 | 1/H | 逆电感响应 / 19,20 |
| ResponseScope | 3 | voltage_step | Observer.y10 | V | 有符号电压差 / 21 |
| PhaseScope | 1 | phase_double | Observer.y6 | 双电角rad | 相位测量 / 17 |
| PhaseScope | 2 | phase_error_double | Observer.y13 | 双电角rad | PLL误差 / 24 |
| ADCScope | 1,2,3 | ia,ib,ic | MeasuredABC.y1,y2,y3 | A | 偏置/量化后 / 28,29,30 |
| ADCScope | 4 | i_zero | Clarke.y3 | A | (ia+ib+ic)/3 / 37 |
| ControlScope | 1 | scale | Inputs.y2 | 1 | 注入比例 / 31 |
| ControlScope | 2 | enable | Inputs.y3 | 逻辑 | 使能 / 32 |
| ControlScope | 3 | reset | Inputs.y4 | 逻辑 | 复位 / 33 |
| ControlScope | 4 | carrier | Observer.y12 | ±1 | 载波 / 23 |
| CalibrationScope | 1 | inverse_average_nominal | NominalInverseAverage | 1/H | 名义参数推导值，未单独记录到trace |
| CalibrationScope | 2 | inverse_average_external | ExternalInverseAverage | 1/H | 测试配置值，未单独记录到trace |
| CalibrationScope | 3 | inverse_average_used | Observer.y15 | 1/H | 实际采用值 / 38 |

完整trace38列：1–2实际uαβ；3–4观测器iαβ；5–6无ADC误差的物理iαβ；7θtrue；8ωtrue；9Te[N·m]；10–11物理id/iq；12–25前14个观测器输出；26π等价轴误差；27完整角误差；28–30测得abc；31scale；32enable；33reset；34–35送观测器的电压αβ（可晚一拍）；36load[N·m]；37零序电流；38新增实际采用逆电感均值。前37列顺序保持。未接Scope的5、6、9、34–36列仍由ToWorkspace保存，不写成已有Scope通道。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $L_{dh},L_{qh},L_{dqh}$ | hfi_parameters返回cfg.Ld / cfg.Lq / cfg.CrossInductance | H | 标称增量参数；原表mH乘$10^{-3}$ |

### 本模块局部量

$L_{dh},L_{qh},L_{dqh}=L_{qdh}$表示本局部张量的增量自感与交叉增量电感。工程Ld/Lq/CrossInductance为标称值，单位H；实际饱和对象的瞬时增量Ld随电流改变。$\theta_{axis}$为有π歧义的连续估计轴线，不能在极性资格前当作完整$\hat\theta_r$。 $\ell_{iso}$是各向同性增量电感H；$I_{pk,+},I_{pk,-}$是正负脉冲扣基线后的电流峰值A，保留$P$作为极对数。
