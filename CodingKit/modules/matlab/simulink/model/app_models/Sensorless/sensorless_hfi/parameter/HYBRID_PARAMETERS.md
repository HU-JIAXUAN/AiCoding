# 物理HFI↔EEMF闭环：参数、信号与Scope

对应`src/SensorlessHFIHybrid.slx`。配置入口为[hfi_hybrid_app_parameters.m](hfi_hybrid_app_parameters.m)、[hfi_hybrid_test_parameters.m](hfi_hybrid_test_parameters.m)，初始化为`initialize_hfi_hybrid('SensorlessHFIHybrid')`。本页按实际接线登记，不与独立融合测试台的解析输入混用。

## 配置参数

| 名称 | 默认值 | 单位 | 定义与作用 |
|---|---|---|---|
| Test.Ts / PlantStep / Duration | 50e−6 / 2.5e−6 / 2.3 | s | 观测/电流周期、ode4步长、仿真时长；测试入口 |
| Test.InitialElectricalSpeed / SpeedReference / ReturnSpeed | 0 / 25 / 8 | 电角rad/s / 机械rad/s / 机械rad/s | 初始、加速及降速请求 |
| Test.CommandTime / ReturnTime | .14 / 1.4 | s | 请求变化时刻；实际给定再经过SpeedProfile限斜率 |
| Test.LoadTorque / LoadTime | .02 / .9 | N·m / s | 外部负载阶跃 |
| Motion.SpeedLimit / AccelerationLimit | 35 / 40 | 机械rad/s / rad/s² | 合成Profile配置，不改变HFI自身适用速度 |
| Motion.NaturalFrequency / Damping | 30 / .9 | rad/s / 1 | 本App速度环设计量，Kp、Ki由J/B/Kt计算；不修改共用motion默认值 |
| Reference.SpeedKp / SpeedKi / SpeedKaw | .0269 / .45 / 20 | N·m/(rad/s)、N·m/rad、1/s | 1 ms速度PI实际转矩增益与回算系数；改NaturalFrequency后重新初始化以同步派生量 |
| HFI | 5 V、30 Hz双角PLL、300 Hz解调低通 | SI | 继承[HFI参数](../../../../lib/观测器/高频注入/parameter/README.md)；实测逆电感均值、探针和极性阶段继续共用 |
| EMF.Rs / Ld / Lq | 与本次名义电机参数相同 | Ω / H / H | IPMSM的EEMF，允许在实验参数中独立覆盖失配；不读取对象真实状态 |
| EMF.BandwidthHz / MinEmf / MinOmega / MaxResidual | 300 / 1 / 30 / 1.5 | Hz / V / 电角rad/s / A | 电流/反电势观测极点设计、幅值、方向速度及残差资格 |
| EMFPLL | 40 Hz、Ts=50 μs、幅值下限1 | SI | 独立于HFI双角PLL；配置由[PLL入口](../../../../lib/相位跟踪/parameter/angle_tracking_parameters.m)生成 |
| Fusion.LowOmega / HighOmega / LowMaxOmega | 40 / 60 / 80 | 电角rad/s | 低高速重叠区及低速来源上限 |
| Fusion.InjectionResumeOmega / InjectionOffOmega | 65 / 75 | 电角rad/s | 提前恢复与高速撤除注入的迟滞 |
| Fusion.QualificationTime / LossTime / BlendTime / InjectionRampTime | .01 / .002 / .05 / .02 | s | 资格、来源失效、正常权重和注入比例时间尺度 |
| Fusion.AllowHighStart | 0 | 0/1 | 首版物理装配先经HFI识别极性；独立融合库的带速取得资格不计为本App已验证能力 |
| Hybrid.InitialDirection / DirectionThreshold | 1 / 5 | ±1 / 电角rad/s | 明确配置的初始方向、估算速度过零保持区；设置在App参数入口 |
| Test.HighQualificationGate | 1 | 0/1 | 只能撤销EEMF资格的故障工况开关，不能强制生成有效资格 |
| Current / Reference | 500 Hz电流PI、1 ms速度PI更新 | SI | 继续共用[FOC控制参数](FOC_PARAMETERS.md)，速度环使用omega_base，坐标跟踪消费实际角修正 |
| Motor / Inverter / ADC及延迟 | 见组合入口与继承配置 | SI | 非线性磁链Jacobian、正常J/B、48 V平均逆变器；ADC、执行/采样年龄沿用[测试参数](hfi_foc_test_parameters.m)和[FOC说明](FOC_PARAMETERS.md) |

Fusion的全部配置、派生量及20个状态见[通用融合参数页](../../../../lib/无感切换/parameter/FUSION_PARAMETERS.md)。修改周期需同步HFI、Probe、Polarity、EMF、两路PLL、Fusion、Current、Profile、刺激表及求解步长。本装配沿用`hfiFocTestCfg`工作区变量名承接原测试块，但实际值由新的hybrid测试入口产生。

## 输入信号

`testStim`共11列，FromWorkspace按Ts逐行读取、关闭插值。

| 列 | 名称 | 单位/类型 | 来源与用途 |
|---|---|---|---|
| 1 | load_torque | N·m，double | 物理对象外部负载 |
| 2 / 3 | enable / reset | 0/1，double兼容 | 全局使能与复位 |
| 4–6 | noise_abc | A，double | 三相ADC噪声/故障偏置 |
| 7 | qualification_gate | 0/1 | 探针凸极资格的故障门控；撤销后可触发极性阶段故障 |
| 8 | speed_request | 机械rad/s | 经Profile限幅/限斜率后进入速度PI |
| 9 / 10 | torque_request / mode | N·m / 枚举 | 0直接转矩、1速度控制 |
| 11 | high_qualification_gate | 0/1 | 与EEMF自身valid相与，只能撤销高端来源 |

融合库输入取自低速完整位置与EEMF输出。两路都消费Measurement的采样电流和VoltageStage对齐后的实际作用电压；后者是理想MIL已知执行支路，不等于硬件上已经具备同样精度的电压测量。对象真实θ/ω仅进入记录、Scope和离线误差。

## 过程变量

| 名称 | 单位/初值 | 所在块与用途 |
|---|---|---|
| Position原探针/轴线/极性状态 | 见各lib | 启动快照、连续HFI、暂停注入双脉冲、恢复完整极性位置 |
| Position.FusionInjection | 0…1，组合量 | Polarity的HFI许可乘Fusion注入比例，接Axis.u5；极性脉冲请求独立于正常HFI撤除 |
| EEMF四状态、独立PLL状态 | A/A/V/V及PLL状态，初始0 | 共用EmfObserver/EEMF；方向改变按库契约复位 |
| Direction | ±1，默认+1 | UnitDelay，供本拍EEMF使用；下一状态只根据融合估速更新，过零保持；无真实速度反馈 |
| Fusion二十状态 | 见通用参数页 | 双向资格、π重接、注入迟滞、加权、预测及故障锁存 |
| omega_base / omega_frame | 电角rad/s | 转速估计 / 融合控制角变化率；速度环与FF用前者，后者用于核对坐标变化 |
| Controller.ExtraAngle | 电角rad | wrap(theta[k]−theta[k−1]−Ts·omega_base[k−1])，送FrameTrackingPI转移坐标状态 |
| Supervisor三个状态 | 0，标志/拍/故障 | 对Fusion.valid和测量电流监控；使用最终融合资格，HFI高速暂停不单独触发整机失锁 |

Fusion状态输出的注入比例打断本拍资格反馈形成的代数环。持续丢失来源时先退出电流控制，再由App锁存故障。0 V平均逆变器仍有电气连接，不代表功率级高阻关断。

## 输出信号

原九份日志保持列顺序：plant_trace(10)、probe_trace(16)、axis_trace(15)、polarity_trace(16)、controller_trace(25)、voltage_trace(8)、adc_trace(4)、angle_error(1)、state_trace(10)，详见[FOC列说明](FOC_PARAMETERS.md)。本模型angle_error记录融合角减真实角；controller_trace中的估速来自omega_base。

新增三份日志如下，均为Structure With Time、50 μs、不截断：

| 日志 | 实际顺序 | 单位 |
|---|---|---|
| fusion_trace，17列 | theta、omega_base、omega_frame、valid、beta、injection、mode、fault、low_qualified、high_qualified、extra_pi、phase_gap、low_count、high_count、loss_count、phase_correction、branch_ready | 逐列见[融合接口](../../../../lib/无感切换/parameter/FUSION_PARAMETERS.md) |
| emf_trace，12列 | theta、omega、valid、e_alpha、e_beta、i_hat_alpha、i_hat_beta、residual_alpha、residual_beta、phase_measured、emf_magnitude、phase_error | rad、rad/s、1、V、V、A、A、A、A、rad、V、rad |
| observer_state_trace，4列 | Direction.y1、Inputs.y11、EEMF.y3、HighValidDouble.y1 | ±1、输入Gate、自身valid、门控后valid |

## Scope 通道

下表完整列出本模型15组Scope，均一个向量输入；与原FOC相比AngleScope增加了两路候选，ValidityScope改为最终融合资格。机械速度与电角速度分开读取。

| Scope | 按实际通道顺序的名称 / 来源 | 单位 |
|---|---|---|
| SpeedScope | 1给定ControllerSignals.y1；2真实机械速度Physical.y4/PolePairs；3估算机械速度ControllerSignals.y2 | 机械rad/s |
| CurrentScope | 1id参考ControllerSignals.y7；2iq参考y6；3测量id y8；4测量iq y9 | A |
| TorqueScope | 1转矩请求ControllerSignals.y5；2真实电磁转矩Physical.y5；3负载Inputs.y1 | N·m |
| AngleScope | 1真实角Physical.y3；2融合角Fusion.y1；3包角误差AngleError；4HFI完整候选Position.y2；5EEMF角EEMF.y1 | 电角rad |
| ValidityScope | 1最终资格Fusion.y4；2控制接通ControlDouble；3App故障Supervisor.y3；4极性故障Polarity.y14 | 0/1或枚举 |
| StartupScope | 1极性阶段Polarity.y8；2极性已知y6；3双侧峰值差y11；4探针运行Position.y8 | 枚举、0/1、A、0/1 |
| VoltageScope | 1实际α电压VoltageSignals.y1；2实际β y2；3限幅α y3；4限幅β y4；5限幅比例y8 | V、V、V、V、1 |
| IntegralScope | 1Ibase_d ControllerSignals.y14；2Ibase_q y15；3回算残差d y16；4回算残差q y17 | V，积分项为电压贡献 |
| FrameScope | 1额外角修正ControllerSignals.y20；2跟踪标志y21；3控制接通y22 | rad、0/1、0/1 |
| FusionScope | 1基波权重Fusion.y5；2HFI比例y6；3低速合格y9；4基波合格y10；5附加π y11；6分支确认y17 | 1或0/1 |
| EMFSpeedScope | 1真实Physical.y4；2HFI Position.y3；3EEMF.y2；4Fusion.y2基准；5Fusion.y3坐标变化率 | 电角rad/s |
| EMFVoltageScope | 1估计eα EEMF.y4；2eβ y5；3幅值y11 | V |
| EMFResidualScope | 1估计减测量电流α EEMF.y8；2β y9 | A |
| FusionPhaseScope | 1两路相位差Fusion.y12；2本拍附加相位修正y16 | 电角rad、rad/拍 |
| FusionStateScope | 1融合模式Fusion.y7；2融合故障y8；3基波valid EEMF.y3；4故障Gate Inputs.y11；5方向Direction.y1 | 枚举、枚举、0/1、0/1、±1 |

Scope块数量不代表需要同时打开窗口。先看FusionScope、ValidityScope定位交接，再按问题查看电流、转矩、相位或残差，完成后关闭。
