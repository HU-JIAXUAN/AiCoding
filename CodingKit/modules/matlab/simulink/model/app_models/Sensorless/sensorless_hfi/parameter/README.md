# App参数与信号

本页保留SensorlessHFIStartup的配置与实际通道。新增SensorlessHFIFOC使用[hfi_foc_app_parameters.m](hfi_foc_app_parameters.m)、[hfi_foc_test_parameters.m](hfi_foc_test_parameters.m)；其配置、输入/过程/输出及九组Scope独立登记在[FOC_PARAMETERS.md](FOC_PARAMETERS.md)，不混用两模型列号。

混合模型使用[hfi_hybrid_app_parameters.m](hfi_hybrid_app_parameters.m)和[hfi_hybrid_test_parameters.m](hfi_hybrid_test_parameters.m)，完整输入、过程、输出和15组Scope见[HYBRID_PARAMETERS.md](HYBRID_PARAMETERS.md)；`initialize_hfi_hybrid`重新加载。

## 配置参数

[hfi_startup_app_parameters.m](hfi_startup_app_parameters.m)组合`Test/HFI/PLL/Probe/Polarity/Motor`六组配置；[hfi_startup_test_parameters.m](hfi_startup_test_parameters.m)定义本App工况。重载与单次覆盖见[运行方法](../build_process/USAGE.md)。

| 名称 | 默认值 | 单位 | 含义/定义 |
|---|---|---|---|
| Test.Ts / PlantStep / Duration | 50e−6 / 2.5e−6 / .3 | s | 采样、ode4步长、停止时刻；测试参数入口 |
| InitialElectricalAngle / InitialElectricalSpeed | .7 / 0 | 电角rad / rad/s | 仅Plant初始化；机械位置/速度分别除极对数 |
| SaturationDepth / CrossInductance / MechanicalEnabled | .25 / 0 / 1 | 1 / H / 0或1 | 物理磁极饱和、交叉增量电感、正常自由机械运动 |
| Enable / Reset / LoadTorque | 1 / 0 / 0 | 逻辑 / 逻辑 / N·m | 默认命令及恒负载 |
| MeasurementNoise / NoiseSeed | 0 / 42 | A RMS / 整数 | 每相独立噪声与复现实验种子 |
| CurrentOffset | [0;0;0] | A | 三相ADC偏置 |
| CurrentResolution / CurrentRange | 0 / 8 | A | 量化步距，0关闭；ADC范围±8 A |
| ActuationGain / ExecutionDelay | 1 / 0 | 1 / 0或1拍 | 实际电压比例与执行延迟 |
| CurrentDelay / VoltageAlignmentDelay | 0 / 0 | 0或1拍 | 电流采样年龄、送观测器的电压年龄；成对调整用于对齐实验 |
| PulseNegativeGain | 1 | 1 | 仅负脉冲的执行比例，故障实验用于不等伏秒 |
| PulseFaultOffsetA | 0 | A | 仅正脉冲期间给a相ADC注入额外偏置，检查启动过流退出 |
| QualificationGate | 1 | 0/1 | 与探针资格相与，检查资格丢失后的锁存故障 |
| HFI.UseMeasuredInverseAverage | 1 | 0/1 | App启用实测均值；HFIAxis第8输入来自探针快照 |
| HFI / PLL | 库默认，周期与Test同步 | SI | [轴线参数说明](../../../../lib/观测器/高频注入/parameter/README.md)，注入5 V、双角PLL 30 Hz |
| Probe | 库默认，Ts及CrossPhase同步 | SI | [探针参数说明](../../../../lib/观测器/高频注入/parameter/PROBE_PARAMETERS.md)，5 V正交激励 |
| Polarity | 库默认，Ts同步 | SI | [双脉冲参数说明](../../../../lib/观测器/高频注入/parameter/POLARITY_PARAMETERS.md)，4 V、1 ms双脉冲 |
| Motor | 本App物理实例 | SI | [高频PMSM参数](../../../../lib/永磁同步电机/parameter/HF_PARAMETERS.md)，Rs=.5 Ω、Ld=1 mH、Lq=1.5 mH、磁链.035 Wb、p=4、J=5e−4 kg·m²、B=1e−4 N·m·s/rad |

## 输入信号

`testStim`由[hfi_startup_stimulus.m](../build_process/hfi_startup_stimulus.m)生成，FromWorkspace在Ts采样且不插值。

| 列 | 名称 | 单位/类型 | 来源及作用 |
|---|---|---|---|
| 1 | load | N·m，double | 物理负载，正号阻碍正转 |
| 2–3 | enable / reset | 逻辑兼容double | 启动、清除状态；reset优先 |
| 4–6 | noise_a / b / c | A，double | 三相ADC噪声，来自固定种子 |
| 7 | qualification_gate | 0/1 | 独立资格故障注入；实际准入仍需探针done/qualified |

内部库输入为实际uαβ、采样iαβ和各自资格；真实角度没有进入算法输入。

## 过程变量

| 名称 | 初值/单位 | 所在块及作用 |
|---|---|---|
| ProbeStage / ProbeSnapshot | 16元素0，混合 | Enabled Subsystem执行探针，输出经一拍UnitDelay交接；停算时保持快照 |
| ProbeDoneMemory / RunProbe | 0 / 逻辑 | 完成后关闭探针；禁能和复位时重新运行以清除旧状态 |
| inverse_average_measured | 0，1/H | Probe.y7→Axis.u8，轴线实际采用值见Axis.y15 |
| Axis状态/双角PLL | 库初值 | 两个电流、电压历史、向量低通、双角锁相；[库参数表](../../../../lib/观测器/高频注入/parameter/README.md) |
| PolarityStates | 19元素0 | 等轴线、停HFI、正脉冲、衰减、负脉冲、衰减、恢复跟踪/故障；[状态索引](../../../../lib/观测器/高频注入/parameter/POLARITY_PARAMETERS.md#过程变量) |
| ExecutionMemory / VoltageMemory / CurrentMemory | [0;0] | 三种可选一拍年龄，测试实际执行与观测信号对齐 |
| PhaseADC / Clarke | 无状态 | 三相偏置→噪声→限幅→量化→Clarke，零序仅记录 |
| AxisError / FullError | rad | .5wrap(2Δθ)与wrap(Δθ)，真实θ只用于评分 |

## 输出信号

本App为自包含物理测试模型，输出由六个ToWorkspace日志记录。每个采样时刻均为Ts，`Structure With Time`，不截断点数。

| 变量 | 列顺序 | 单位及用途 |
|---|---|---|
| plant_trace，13列 | 实际uαβ(1–2)、送估算器iαβ(3–4)、真实θ(5)、真实ω(6)、Te(7)、物理id/iq(8–9)、enable(10)、reset(11)、使用的凸极资格(12)、RunProbe(13) | V、A、电角rad、rad/s、N·m、A、状态 |
| probe_trace，16列 | 按SaliencyProbe y1–y16输出顺序 | [完整顺序/单位](../../../../lib/观测器/高频注入/parameter/PROBE_PARAMETERS.md#输出信号) |
| axis_trace，15列 | 按HFIAxis y1–y15输出顺序 | [完整顺序/单位](../../../../lib/观测器/高频注入/parameter/README.md#输出信号) |
| polarity_trace，16列 | 按PolarityPulse y1–y16输出顺序 | [完整顺序/单位](../../../../lib/观测器/高频注入/parameter/POLARITY_PARAMETERS.md#输出信号) |
| error_trace，2列 | π等价轴误差、完整角误差 | 电角rad；完整角仅position_valid为1时供控制使用 |
| adc_trace，4列 | 测得ia、ib、ic、零序电流 | A |

`theta_full=wrap(theta_axis+π·flip_pi)`；`position_valid`需要极性已识别、TRACK阶段、连续HFI锁定和凸极资格。仅有axis_valid或探针qualified均不足以放行完整位置。

## Scope 通道

每组Scope一个向量输入，下表严格按实际向量顺序；括号中的日志列仅方便定位，不是Scope端口号。

| Scope | 通道 | 名称 | 来源 | 单位/类型 | 观察内容 |
|---|---|---|---|---|---|
| AngleScope | 1,2,3,4 | theta_true,theta_axis,theta_full,full_error | Physical.y3,Axis.y3,Polarity.y4,FullError | 电角rad | π歧义及极性恢复；plant5/axis3/polarity4/error2 |
| SpeedScope | 1,2,3 | omega_true,omega_axis,speed_filtered | Physical.y4,Axis.y4,Polarity.y16 | 电角rad/s | 真实运动与脉冲准入 |
| ValidityScope | 1,2,3,4 | probe_qualified,axis_valid,polarity_known,position_valid | Probe.y5,Axis.y5,Polarity.y6,y5 | 0/1 | 各阶段资格区别 |
| StageScope | 1,2,3,4 | polarity_stage,fault_code,probe_quality_code,run_probe | Polarity.y8,y14,Probe.y16,RunProbeDouble | 枚举/逻辑 | 阶段、故障与探针停算 |
| PeakScope | 1,2,3 | peak_positive,peak_negative,peak_difference | Polarity.y9,y10,y11 | A | 基线修正的饱和差 |
| DoseScope | 1,2 | dose_positive,dose_negative | Polarity.y12,y13 | V·s | 实际执行脉冲是否可比较 |
| CalibrationScope | 1,2,3 | inverse_average_nominal,measured,used | NominalInverseAverage,Probe.y7,Axis.y15 | 1/H | 名义、实测、实际采用值 |
| VoltageScope | 1,2,3,4,5,6 | actual_uα,uβ,pulse_uα,uβ,HFI_uα,uβ | ActualVoltage.y1,y2,Polarity.y1,y2,Axis.y1,y2 | V | 探针/脉冲/HFI分时与实际执行 |
| ADCScope | 1,2,3,4 | ia,ib,ic,i_zero | MeasuredABC.y1,y2,y3,Clarke.y3 | A | 噪声、量化、偏置、故障注入 |

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | Test.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | Motor.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | Motor.Ld / Motor.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | Motor.Flux | Wb | 直接使用 |
| $P$ | Motor.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\theta_r$ | Test.InitialElectricalAngle | 电角rad | 初始真实角；Motor.Position0=本字段/P |
| $\omega_m$ | Motor.Speed0 | 机械rad/s | rpm乘$2\pi/60$；与电角速度通过P换算 |

### 本模块局部量

$\theta_{ctrl}$为融合控制角，$\theta_{axis}$为有π歧义的估计轴线；完整估计位置才写$\hat\theta_r$。Motor.CrossInductance为常交叉耦合项H，Motor.B为局部旋转阻尼$b_{rot}$；HFI张量标称值与饱和对象瞬时增量值分开。
