# 参数与信号

新增四种物理App的M入口、输入/过程/输出和实际Scope通道见[EXTENSION_PARAMETERS.md](EXTENSION_PARAMETERS.md)。入口[extension_foc_parameters.m](extension_foc_parameters.m)，加载后用`initialize_extension_foc(model,kind)`重读；旧六列与新增七列工况格式分开。

## 配置参数

新增带速App的独立配置入口为[flying_foc_parameters.m](flying_foc_parameters.m)，输入/状态、34/19/29列日志及七组Scope见[FLYING_PARAMETERS.md](FLYING_PARAMETERS.md)，重新加载用`initialize_flying_foc('FlyingFluxFOC')`或`run_flying_foc_case(p)`。

本页原表对应SMO App；EEMF/Flux由[observer_foc_parameters.m](observer_foc_parameters.m)配置，新增字段、状态、日志和逐通道说明见[OBSERVER_PARAMETERS.md](OBSERVER_PARAMETERS.md)。共同电机/控制配置继续复用下表。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| currentCfg.Ts | 50e-6 | s | [sensorless_foc_parameters.m](sensorless_foc_parameters.m) |
| experimentCfg.Step / Duration | 5e-6 / 2 | s | Plant步长与时长，定义文件同上 |
| pmsmCfg.Rs / Ld / Lq / Flux | 0.5 / 0.001 / 0.001 / 0.035 | Ω / H / H / Wb | 本App SPMSM覆盖，定义文件同上 |
| focCfg.SpeedReference / CurrentMax | 80 / 8 | 机械rad/s / A | 速度目标及闭环电流参考限制，定义文件同上 |
| timingCfg.FeedbackTicks / ActuationTicks | 0 / 1 | 控制拍 | 首个闭环从零额外反馈年龄开始，保留执行延迟 |
| refCfg.SpeedKaw | 1000 | 1/s | 1/SpeedTs；接管前用残差实现一拍积分跟踪 |
| handoverCfg.AllowFlying | 0 | 1 | 首版关闭飞行捕获 |
| pmsmCfg.PolePairs / J / B / Position0 | 4 / 5e-4 / 1e-4 / 0.1 | 1 / kg·m² / N·m·s/rad / 机械rad | 电机和负载实例，定义文件同上 |
| currentCfg.Kaw | 20000 | 1/s | 1/Ts，对齐时跟踪所选电压；电流PI的Kp、Ki由电机参数函数生成 |
| refCfg.SpeedTs / SpeedKp / SpeedKi | 0.001 / 约0.0179 / 约0.2 | s / N·m·s/rad / N·m/rad | 速度PI，精确值读取本模块返回结构体 |
| motionCfg.SpeedLimit / AccelerationLimit | 120 / 200 | 机械rad/s / rad/s² | 速度命令限值和斜率 |
| focCfg.VoltageAlignmentEnable / AlignmentVoltageGain | 1 / 0.5 | 1 / Ω | 对齐阶段选择电压及增益 |
| focCfg.FrameCorrectionTolerance | 1e-10 | rad | 识别额外坐标变化的数值容差 |
| focCfg.CommandTime / LoadTime / LoadTorque | 0.05 / 0.9 / 0.1 | s / s / N·m | 默认命令和负载事件 |
| focCfg.Enable / Reset / ObserverEnable / Direction | 1 / 0 / 1 / 1 | 逻辑 / ±1 | 默认工况开关和已知起转方向 |

完整配置由[sensorless_foc_parameters.m](sensorless_foc_parameters.m)返回，刺激由[sensorless_foc_stimulus.m](sensorless_foc_stimulus.m)生成，验证场景和阈值在[sensorless_foc_validation_parameters.m](sensorless_foc_validation_parameters.m)。修改默认值后执行`initialize_sensorless_foc('SensorlessFOC')`重新载入模型工作区。单次覆盖示例见[USAGE.md](../build_process/USAGE.md)。

## 输入信号

[sensorless_foc_stimulus.m](sensorless_foc_stimulus.m)生成6列：机械速度请求(rad/s)、负载(N·m)、enable、reset、direction、observer_enable。后4列为逻辑兼容double，direction只能±1。事件按整数采样索引定义。

## 过程变量

[sensorless_foc_channels.m](sensorless_foc_channels.m)定义实际四组日志的数据布局，包括变量名、单位、宽度和构建源信号。逐列说明见[TRACE_CHANNELS.md](TRACE_CHANNELS.md)。主要状态如下。

| 名称 | 单位/初值 | 来源 | 作用 |
|---|---|---|---|
| theta_start / id_start / iq_start | rad / A；初始0 | Startup | 软件电流场角及起转参考 |
| startup_mode / startup_fault | 整数；初始0 | Startup | 0关、1飞行窗口、2预对齐、3对齐、4爬升、5等待、6接管、7故障；当前App关闭飞行捕获 |
| theta_used / beta / handover_mode | rad / 0..1 / 整数 | Handover | 控制角、混合权重；模式0关、1启动、2资格、3混合、4AUTO、5故障 |
| omega_base / omega_frame | 电角rad/s | Handover | 估算基速 / 包含规划坐标偏移变化的坐标速度，不能互换 |
| integral_base / integral_state | V；初始[0;0] | CurrentPI | 当前计算使用的变换积分 / 上一积分状态 |
| delta_extra / track | rad / 逻辑 | Controller | 除正常旋转之外的坐标纠正及积分状态跟踪请求 |
| voltage_alignment / voltage_selected | 逻辑 / V | Controller | 当前是否电压对齐及最终所选dq请求 |
| pi_residual / voltage_residual | V | Controller / VoltageStage | PI实际使用的跟踪残差 / 执行链可实现电压残差 |
| integral_torque / torque_estimated | N·m | SpeedPI / 估算坐标电流 | 速度积分及接管前跟踪转矩，不读取Plant真实转矩 |
| qualification_count / loss_count | 采样拍数；初始0 | Handover | 连续资格与失锁累计；阈值由handoverCfg派生 |

## 输出信号

SMO四组Structure With Time日志分别为`plant_trace`13列、`observer_trace`20列、`controller_trace`46列、`actuation_trace`26列，数据为double，全部50 μs。运行器返回`r.<stage>.trace`和`r.<stage>.columns`，并保存实际参数和输入。列号见[TRACE_CHANNELS.md](TRACE_CHANNELS.md)。

## Scope 通道

下表对应原SMO App的现有Scope，每个Scope有一个向量输入，编号按向量元素依次排列。两份新App保留Plant/Controller Scope，Observer的五组Scope详见[差异通道表](OBSERVER_PARAMETERS.md#新-app-的-observer-scope)。控制坐标与真实转子坐标电流分开观察。

| 所在子系统 / Scope | 通道顺序、单位 | 来源 / 观察内容 |
|---|---|---|
| Plant / RotorCurrentScope | 1 id_true(A)，2 iq_true(A) | Electrical，真实转子坐标电流 |
| Plant / MechanicalSpeedScope | 1 speed_true(机械rad/s) | Mechanical，实际机械速度 |
| Plant / TorqueScope | 1 torque_true，2 load_torque(N·m) | Electrical / 工况负载，起转和负载恢复 |
| Observer / EstimateAngleScope | 1 theta_hat(电角rad) | SMO，估算包角 |
| Observer / EstimateSpeedScope | 1 omega_hat(电角rad/s) | SMO，机械速度需除PolePairs |
| Observer / EmfScope | 1 emf_alpha，2 emf_beta，3 emf_magnitude(V) | SMO，反电势幅值及相位 |
| Observer / ValidityScope | 1 valid，2 enable，3 reset(0/1) | SMO及输入，估算有效性和复位 |
| Controller / CurrentScope | 1 d_ref，2 q_ref，3 d_measured，4 q_measured(A) | ReferenceBlend / ControlCurrent，均在theta_used坐标中 |
| Controller / AngleScope | 1 theta_start，2 theta_hat，3 theta_used(电角rad) | Startup / Observer输入 / Handover，接管角连续性 |
| Controller / FrameSpeedScope | 1 omega_start，2 omega_base，3 omega_frame(电角rad/s) | Startup / Handover，基速和坐标速度差异 |
| Controller / TransitionScope | 1 beta(0..1)，2 track(0/1) | Handover / TrackDouble，参考混合与状态跟踪 |
| Controller / ExtraAngleScope | 1 delta_extra(rad) | ExtraAngle，额外坐标纠正 |
| Controller / StateScope | 1 startup_mode，2 startup_fault，3 handover_mode，4 handover_fault，5 run | Startup / Handover，整数状态和命令退出 |
| Controller / SpeedLoopScope | 1 speed_reference，2 held_speed_estimate(机械rad/s) | 限斜率命令 / omega_base除PolePairs，实际Plant速度另看Plant Scope |
| Controller / TorqueLoopScope | 1 torque_request，2 torque_allocated，3 torque_estimated(N·m) | SpeedPI / AllocatedTorque / EstimatedTorqueSample，外环跟踪和限流 |
| Controller / VoltageScope | 1 v_PI_d，2 v_PI_q，3 residual_d，4 residual_q(V) | CurrentPI / VoltageStage残差；对齐时所选电压另看controller日志43–44列 |

慢速控制量在Scope中按自身采样周期显示。四组保存日志则统一到50 μs；日志同步的实现和限制见[USAGE.md](../build_process/USAGE.md#读scope和日志)。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | currentCfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | pmsmCfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | pmsmCfg.Ld / pmsmCfg.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | pmsmCfg.Flux | Wb | 直接使用 |
| $P$ | pmsmCfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r,\hat\omega_r$ | Observer输出1、2 | 电角rad / rad/s | 估计机械速度为输出2除P；各App诊断输出另按实际表 |
| $\omega_m$ | pmsmCfg.Speed0 | 机械rad/s | rpm乘$2\pi/60$；与电角速度通过P换算 |
| $V_{dc}$ | inverterCfg.Vdc / bridgeCfg.Vdc / fwCfg.BusValues | V | 原平均、带速和扩展物理App分别按对应参数入口配置 |

### 本模块局部量

$\ell_{sp}=L_d=L_q$用于SPMSM，$\theta_{phase}$是送PLL的测量相位，$\theta_{ctrl}$是控制坐标角；均不重定义原表$\theta_m,\theta_c$。旋转算子用$\mathcal Q$，转动惯量仍用$J$。新增四物理App的额外映射见[EXTENSION_PARAMETERS](EXTENSION_PARAMETERS.md)。
