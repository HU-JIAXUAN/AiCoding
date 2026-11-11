# HFI 电流/速度闭环参数与实际通道

对应`src/SensorlessHFIFOC.slx`；位置启动独立模型继续见[本目录README](README.md)。数值默认值由[hfi_foc_app_parameters.m](hfi_foc_app_parameters.m)和[hfi_foc_test_parameters.m](hfi_foc_test_parameters.m)维护，初始化函数为[initialize_hfi_foc.m](../build_process/initialize_hfi_foc.m)。

## 配置参数

| 名称 | 默认值 | 单位 | 定义与作用 |
|---|---|---|---|
| Test.Ts / PlantStep / Duration | 50e−6 / 2.5e−6 / 1.2 | s | 电流/观测周期、ode4步长、时长；测试参数入口 |
| Test.SpeedInitial / SpeedReference / CommandTime | 0 / 8 / .14 | 机械rad/s / rad/s / s | 原始速度指令及变化时刻 |
| Test.Mode / TorqueReference | 1 / .02 | 枚举 / N·m | 1速度闭环，0直接转矩请求；转矩同样在CommandTime后给定 |
| Test.LoadTorque / LoadTime | .02 / .7 | N·m / s | 外部恒定负载阶跃，正负号按统一机械方向 |
| Test.InitialElectricalAngle / InitialElectricalSpeed | .7 / 0 | 电角rad / rad/s | 仅物理对象初始状态 |
| Test.SaturationDepth / CrossInductance / MechanicalEnabled | .25 / 0 / 1 | 1 / H / 逻辑 | 正常机械自由运动与合成磁极饱和 |
| Test.Enable / Reset / QualificationGate | 1 / 0 / 1 | 逻辑 | 全局命令及位置资格故障工况 |
| Test.MeasurementNoise / NoiseSeed / CurrentOffset | 0 / 42 / [0;0;0] | A RMS / 整数 / A | 三相ADC噪声、种子和偏置 |
| Test.CurrentResolution / CurrentRange | 0 / 8 | A | 0关闭量化；范围±8 A |
| Test.CurrentDelay / VoltageAlignmentDelay / ExecutionDelay | 0 / 0 / 0 | 0或1拍 | 采样年龄、观测电压年龄、真实执行延迟 |
| Test.ActuationGain / PulseNegativeGain / PulseFaultOffsetA | 1 / 1 / 0 | 1 / 1 / A | 执行比例、负脉冲比例、正脉冲a相ADC故障偏置 |
| Current | 500 Hz，50 μs | SI | [电流PI参数](../../../../lib/电流环/parameter/current_parameters.m)，Ld/Lq名义值设计；Kaw=1000 1/s |
| Reference.SpeedTs / SpeedKp / SpeedKi / SpeedKaw | .001 / .0179 / .2 / 20 | s / N·m·s/rad / N·m/rad / 1/s | 原[机械环参数](../../../../lib/运动环/parameter/motion_parameters.m)转成转矩PI配置 |
| Motion.SpeedLimit / AccelerationLimit | 15 / 40 | 机械rad/s / rad/s² | 速度指令限幅、限斜率；HFI适用范围仍需看实际估算资格 |
| Profile | Ts=50 μs，边界±15，双向40 | SI | [共用SpeedProfile](../../../../lib/运动环/parameter/PROFILE_PARAMETERS.md)；App从Motion限值组合profileCfg，禁能/复位清状态 |
| FOC.CurrentMax / Kt | 2 / .21 | A / N·m/A | q轴参考限值，id参考0；Kt=1.5pψf |
| FOC.FrameCorrectionTolerance | 1e−8 | 电角rad | 超出正常同步旋转的坐标修正触发FrameTrackingPI |
| FOC.MaxMeasuredCurrent / PositionLossTime | 8 / .002 | A / s | 采样电流模过限，或已取得位置后连续失效，锁存App故障 |
| FOC.PositionLossSamples / SupervisorSettings | 40 / 2元素 | 拍 / 混合 | 由周期推导；Settings=[MaxMeasuredCurrent,PositionLossSamples] |
| Inverter.Vdc / MinDuty / PwmTs | 48 / .02 / 50e−6 | V / 1 / s | [平均逆变器参数](../../../../lib/逆变器/parameter/inverter_parameters.m)；母线为本次仿真的常量 |
| Inverter.LinearLimit | 26.6043… | V | Vdc/√3·(1−2MinDuty)，同时约束基波和HFI合成请求 |
| Feedforward.Enable / ParameterScale | 1 / 1 | 逻辑 / 1 | [dq前馈](../../../../lib/电压前馈/parameter/feedforward_parameters.m)，实际相加前还受控制使能门控 |
| HFI / PLL / Probe / Polarity / Motor | 共用默认、Ts同步 | SI | [启动组合参数](hfi_startup_app_parameters.m)、[轴线](../../../../lib/观测器/高频注入/parameter/README.md)、[极性](../../../../lib/观测器/高频注入/parameter/POLARITY_PARAMETERS.md)；不复制库默认值到SLX |

所有参数结构体由本App组合。改M文件后重新初始化；单次试验用SimulationInput覆盖对应工作区变量。修改Ld/Lq、极对数或Ts时同步重建相关PI、PLL及派生配置，不能只改一个打包向量。

## 输入信号

`testStim`由[hfi_foc_stimulus.m](../build_process/hfi_foc_stimulus.m)生成，10列、不插值、Ts精确网格：

| 列 | 名称 | 单位/类型 | 来源及作用 |
|---|---|---|---|
| 1 | load | N·m，double | 物理负载，正号阻碍正转 |
| 2–3 | enable / reset | 逻辑兼容double | 禁能/复位清除App锁存及启动状态 |
| 4–6 | noise_a/b/c | A，double | ADC噪声或测量故障注入 |
| 7 | qualification_gate | 0/1 | 与探针资格相与；撤销后位置链退出 |
| 8 | speed_reference | 机械rad/s，double | 经过限速及限斜率后供速度误差使用 |
| 9 | torque_reference | N·m，double | Mode=0时选择的直接转矩请求 |
| 10 | mode | 0或1，double | 0转矩、1速度；两种模式都经电流环 |

真实θ/ω只用于物理方程、Root的误差/Scope和离线验收，不进入Position、Controller或Supervisor的在线判断。电流控制与观测均使用测量链输出。

## 过程变量

| 名称 | 初值/单位 | 所在块及作用 |
|---|---|---|
| Position快照/轴线/极性 | 库初值 | 共用启动积木，探针完成后停算；[启动过程](../build_process/STEPS.md) |
| SupervisorStates | [0;0;0] | UnitDelay；[everAcquired,lossSamples,faultCode]，只由估算资格和测得电流更新 |
| Supervisor故障 | 0 | 1测量非有限/电流模过限；2取得位置后连续失效；保持到外部禁能/复位 |
| MasterActive / ControlActive | 逻辑 | Master=enable&&!reset&&!fault；Control还要求完整位置有效 |
| SpeedPI状态 | 0 N·m | 共用TorquePI；误差、回算、使能、复位均1 ms采样，保证积分按此周期更新 |
| SpeedSlew | 0 rad/s | 共用SpeedProfile，未接通控制时清零，重新接通从0按每拍斜率爬升 |
| 电流PI状态 | 8元素0 | 共用FrameTrackingPI；[状态和公式](../../../../lib/电流环/parameter/FRAME_TRACKING.md)，50 μs更新 |
| delta_extra / track | rad / 逻辑 | wrap(θ[k]−θ[k−1]−ω[k−1]Ts)，超过容差才转换PI坐标状态 |
| feedforward_dq | V[2] | 前馈库输出经ControlActive门控，再与PI相加 |
| TotalVoltage | V[2]，αβ | 基波请求加Position注入请求，进入统一限幅/SVPWM/平均逆变器 |
| residual_ab / residual_dq | V[2] | 同拍PWM指令空间的可行电压减总请求，再按θ_used变换回算；不混入执行流水线旧电压或对象执行增益损失 |
| 实际/观测电压 | V[2] | 执行增益及可选执行延迟后送Plant；观测年龄可另延一拍与电流对齐 |
| LogSample3/4/5/6/23/24/25 | 无附加状态要求 | 只转换诊断支路速率，使25列Controller日志统一50 μs；不改变控制连接 |

外部禁能/复位门控合成电压；可选执行延迟代表一拍实际施加流水线。平均模型输出0 V不等于真实功率级高阻关断。

## 输出信号

以下均为Structure With Time日志，实际记录周期50 μs，完整保留。向量元素顺序为d/q或α/β；电流、电压为相峰值定义。

| 变量 | 列顺序 | 单位 |
|---|---|---|
| plant_trace，10列 | iα,iβ,θe,ωe,Te,id,iq,Ldd,ψd,ψq | A,A,电角rad,rad/s,N·m,A,A,H,Wb,Wb |
| probe_trace，16列 | SaliencyProbe公开输出顺序 | [探针接口](../../../../lib/观测器/高频注入/parameter/PROBE_PARAMETERS.md#输出信号) |
| axis_trace，15列 | HFIAxis公开输出顺序 | [轴线接口](../../../../lib/观测器/高频注入/parameter/README.md#输出信号) |
| polarity_trace，16列 | PolarityPulse公开输出顺序 | [极性接口](../../../../lib/观测器/高频注入/parameter/POLARITY_PARAMETERS.md#输出信号) |
| controller_trace，25列 | 见下表 | 混合 |
| voltage_trace，8列 | 实际uα,uβ；限幅后uα,uβ；duty_a,b,c；圆限幅scale | V,V,V,V,1,1,1,1 |
| adc_trace，4列 | ia,ib,ic,i_zero | A |
| angle_error，1列 | wrap(θfull−θtrue) | 电角rad，仅离线评分 |
| state_trace，10列 | enable,reset,master_active,control_active,everAcquired,lossSamples,app_fault,run_probe,qualification_gate,mode | 状态，lossSamples为拍数 |

| Controller列 | 名称 | 单位 | 来源/用途 |
|---|---|---|---|
| 1–3 | speed_reference_limited,omega_mechanical_hat,speed_error_sampled | 机械rad/s | SpeedSlew、MechanicalSpeed、SampleSpeedError |
| 4–5 | speed_pi_torque,torque_selected | N·m | SpeedPI.y1、TorqueSelect |
| 6–7 | iq_reference_limited,id_reference | A | IqLimit、Zero；禁能时未必为0，是否用于控制还看第22列 |
| 8–9 | id_measured,iq_measured | A | ControlPark，使用完整估算角度 |
| 10–11 | fundamental_vd,vq | V | PI加实际前馈，未包含HFI |
| 12–13 | pi_vd,vq | V | FrameTrackingPI.y1 |
| 14–15 | integral_base_d,q | V | FrameTrackingPI.y2，本拍坐标修正后的积分基值 |
| 16–17 | voltage_residual_d,q | V | ResidualPark |
| 18–19 | applied_feedforward_d,q | V | AppliedFeedforward，禁能为0 |
| 20–22 | delta_extra,track,control_active | 电角rad,0/1,0/1 | ExtraAngle、TrackDouble、active输入 |
| 23–24 | speed_integral,torque_residual | N·m | SpeedPI.y2、TorqueResidual；积分本身1 ms更新，日志50 μs保持 |
| 25 | iq_requested_unlimited | A | TorqueToIq，限流前请求 |

## Scope 通道

每组Scope一个向量输入，下表按实际内部通道顺序；ControllerSignals即上述controller_trace的对应列。

| Scope | 通道 | 名称 | 来源 | 单位/类型 | 观察内容 |
|---|---|---|---|---|---|
| SpeedScope | 1,2,3 | 限速/斜率后给定、真实机械速度、估算机械速度 | ControllerSignals.y1,MechanicalTruth,ControllerSignals.y2 | rad/s | 速度闭环及估算差 |
| CurrentScope | 1,2,3,4 | id_ref,iq_ref,id_hat,iq_hat | ControllerSignals.y7,y6,y8,y9 | A | 电流误差与HFI纹波 |
| TorqueScope | 1,2,3 | 选中转矩、物理Te、负载 | ControllerSignals.y5,Physical.y5,Inputs.y1 | N·m | 负载响应和转矩模式 |
| AngleScope | 1,2,3 | θtrue,θfull,包角误差 | Physical.y3,Position.y2,AngleError | 电角rad | 真值只作对照 |
| ValidityScope | 1,2,3,4 | position_valid,control_active,app_fault,polarity_fault | Position.y4,ControlDouble,Supervisor.y3,Polarity.y14 | 状态 | 启动、失锁、两级故障区别 |
| StartupScope | 1,2,3,4 | polarity_stage,polarity_known,peak_difference,run_probe | Polarity.y8,y6,y11,Position.y8 | 枚举,0/1,A,0/1 | 启动顺序及探针停算 |
| VoltageScope | 1,2,3,4,5 | 实际uα,uβ、限幅后uα,uβ、scale | VoltageSignals.y1,y2,y3,y4,y8 | V,V,V,V,1 | 注入合成、限压与真实执行 |
| IntegralScope | 1,2,3,4 | 电流积分基值d/q、回算残差d/q | ControllerSignals.y14,y15,y16,y17 | V | 反积分饱和与坐标转换 |
| FrameScope | 1,2,3 | delta_extra,track,control_active | ControllerSignals.y20,y21,y22 | rad,0/1,0/1 | 正常旋转与额外角度修正 |
