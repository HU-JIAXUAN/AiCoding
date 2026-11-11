# 共同实验与整机装配：参数与信号

## 配置参数

App全部配置的可执行组合入口为[experiment_app_parameters.m](experiment_app_parameters.m)，返回电机、控制器、逆变器、时序、前馈、死区及工况结构体；场景数值仍由[experiment_parameters.m](experiment_parameters.m)定义。可在组合入口中覆盖本App的电机/控制/平台实例，修改后执行`initialize_motor_model('MotorExperiment')`重新加载模型工作区。全部模块入口见[参数使用索引](../../../../../docs/guide/PARAMETER_USAGE.md)。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| experimentCfg.Step | 0.000005 | s | Plant求解器固定步长；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.LogTs | 0.0001 | s | 记录间隔；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.Duration | 1.5 | s | 有限仿真时长；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.Mode | 2 | 枚举 | 0电流、1速度、2位置，开跑前选择；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.UseInverter | 1 | 1 | 0理想限幅dq，1平均逆变器；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.UseTiming | 1 | 1 | 0采样保持，1再加配置的整数拍延迟；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.UseMechanical | 1 | 1 | 1自由机械响应，0外部原动机恒速；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.ImposedElectricalSpeed | 0 | rad/s | 外部施加电角速度；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.IdReference | 0 | A | d轴给定；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.IqReference | 2 | A | 电流模式阶跃后的q轴给定；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.IqInitial | 0 | A | 电流模式阶跃前值；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.SpeedReference | 40 | rad/s | 速度模式阶跃后值；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.SpeedInitial | 0 | rad/s | 速度模式阶跃前值；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.PositionReference | 1 | rad | 位置阶跃后值；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.PositionInitial | 0 | rad | 位置阶跃前值；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.CommandTime | 0.05 | s | 命令阶跃时刻；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.LoadTorque | 0.1 | N·m | 有符号负载，进入Te−Tl−Bω；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.LoadTime | 0.35 | s | 负载阶跃时刻；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.Enable | 1 | 1 | 功能/控制器使能；不等同门极停机；[experiment_parameters.m](experiment_parameters.m) |
| experimentCfg.Reset | 0 | 1 | 同步电平复位，优先于Enable；[experiment_parameters.m](experiment_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../../../lib/永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../../../lib/逆变器/parameter/inverter_parameters.m)、[时序](../../../../lib/采样执行时序/parameter/timing_parameters.m)、[整机Scope](README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| 位置/速度/电流配置给定 | rad / rad/s / A | double | 外环1ms，电流100µs；功能见搭建步骤 |
| LoadTorque | N·m，有符号负载 | double | 100µs；功能见搭建步骤 |
| Enable / Reset | 1，控制器使能/同步复位 | boolean | 100µs；功能见搭建步骤 |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| TruthFrame / SampleFrame | 混合SI，固定顺序 | FeedbackStage | 电流角度速度位置同帧 |
| 电流参考与误差 | A，[d;q] | MotionStage/CurrentStage | 给定、反馈、真值分开 |
| voltage_request / voltage_pi / voltage_ff | V，[d;q] | CurrentStage | 总请求、PI贡献、FF贡献 |
| feasible_command / voltage_residual | V，[d;q] | VoltageStage | 同拍限制评价点 |
| duty_command / duty_applied | 1，[a;b;c] | VoltageStage | 当前命令与执行后值 |
| Enable | boolean | 配置常量 | 控制器使能，不等同实机门极停机 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| trace | 逐列SI单位 | double[52] | 100µs |
| 状态、反馈、duty与残差 | 见Scope表 | double | 连续或明确采样周期 |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### MotorExperiment

实际Scope块：CurrentsScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id_reference；记录列1 | MotorExperiment/MotionStage 输出2 | A / double | d轴电流给定 |
| 2 | iq_reference；记录列2 | MotorExperiment/MotionStage 输出1 | A / double | q轴电流给定 |
| 3 | id_truth；记录列3 | MotorExperiment/Electrical 输出1 | A / double | 对象d轴真值 |
| 4 | iq_truth；记录列4 | MotorExperiment/Electrical 输出2 | A / double | 对象q轴真值 |
| 5 | id_feedback；记录列5 | MotorExperiment/FeedbackStage 输出1 | A / double | 经过采样/延迟/变换的d轴反馈 |
| 6 | iq_feedback；记录列6 | MotorExperiment/FeedbackStage 输出2 | A / double | 经过采样/延迟/变换的q轴反馈 |

实际Scope块：VoltagesScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | voltage_request_dq_1；记录列7 | MotorExperiment/CurrentStage 输出1 元素1 | V / double | PI+FF总电压请求，元素1=d、2=q |
| 2 | voltage_request_dq_2；记录列8 | MotorExperiment/CurrentStage 输出1 元素2 | V / double | PI+FF总电压请求，元素1=d、2=q |
| 3 | voltage_pi_dq_1；记录列9 | MotorExperiment/CurrentStage 输出2 元素1 | V / double | PI自身输出，元素1=d、2=q |
| 4 | voltage_pi_dq_2；记录列10 | MotorExperiment/CurrentStage 输出2 元素2 | V / double | PI自身输出，元素1=d、2=q |
| 5 | voltage_ff_dq_1；记录列11 | MotorExperiment/CurrentStage 输出3 元素1 | V / double | 使能/复位门控后的FF，元素1=d、2=q |
| 6 | voltage_ff_dq_2；记录列12 | MotorExperiment/CurrentStage 输出3 元素2 | V / double | 使能/复位门控后的FF，元素1=d、2=q |
| 7 | integral_dq_1；记录列13 | MotorExperiment/CurrentStage 输出4 元素1 | V / double | PI积分贡献，元素1=d、2=q |
| 8 | integral_dq_2；记录列14 | MotorExperiment/CurrentStage 输出4 元素2 | V / double | PI积分贡献，元素1=d、2=q |
| 9 | voltage_residual_dq_1；记录列15 | MotorExperiment/VoltageStage 输出6 元素1 | V / double | 同拍可行端电压命令减总请求，元素1=d、2=q |
| 10 | voltage_residual_dq_2；记录列16 | MotorExperiment/VoltageStage 输出6 元素2 | V / double | 同拍可行端电压命令减总请求，元素1=d、2=q |
| 11 | vd_plant；记录列17 | MotorExperiment/VoltageStage 输出1 | V / double | 真正送入Plant的d电压 |
| 12 | vq_plant；记录列18 | MotorExperiment/VoltageStage 输出2 | V / double | 真正送入Plant的q电压 |
| 13 | feasible_command_dq_1；记录列19 | MotorExperiment/VoltageStage 输出7 元素1 | V / double | 同拍限制评价点电压，元素1=d、2=q |
| 14 | feasible_command_dq_2；记录列20 | MotorExperiment/VoltageStage 输出7 元素2 | V / double | 同拍限制评价点电压，元素1=d、2=q |

实际Scope块：DutyScope，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | duty_command_abc_1；记录列21 | MotorExperiment/VoltageStage 输出3 元素1 | 1 / double | 调制器当前命令，元素1/2/3=a/b/c |
| 2 | duty_command_abc_2；记录列22 | MotorExperiment/VoltageStage 输出3 元素2 | 1 / double | 调制器当前命令，元素1/2/3=a/b/c |
| 3 | duty_command_abc_3；记录列23 | MotorExperiment/VoltageStage 输出3 元素3 | 1 / double | 调制器当前命令，元素1/2/3=a/b/c |
| 4 | duty_applied_abc_1；记录列24 | MotorExperiment/VoltageStage 输出4 元素1 | 1 / double | 执行延迟后duty，启动初值全0 |
| 5 | duty_applied_abc_2；记录列25 | MotorExperiment/VoltageStage 输出4 元素2 | 1 / double | 执行延迟后duty，启动初值全0 |
| 6 | duty_applied_abc_3；记录列26 | MotorExperiment/VoltageStage 输出4 元素3 | 1 / double | 执行延迟后duty，启动初值全0 |
| 7 | voltage_limit_scale；记录列27 | MotorExperiment/VoltageStage 输出5 | 1 / double | 调制前圆限制系数 |

实际Scope块：TorquesScope，纵轴：N*m，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | electromagnetic_torque；记录列28 | MotorExperiment/Electrical 输出3 | N*m / double | 电气方程计算的电磁转矩 |
| 2 | load_torque；记录列29 | MotorExperiment/LoadTorque 输出1 | N*m / double | 有符号负载，进入Te−Tl−Bω |

实际Scope块：SpeedScope，纵轴：rad/s，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | speed_request；记录列30 | MotorExperiment/MotionStage 输出3 | rad/s / double | 外环限速/限斜率后的机械速度给定；电流模式下仅为诊断 |
| 2 | speed_truth；记录列31 | MotorExperiment/MechanicalSpeed 输出1 | rad/s / double | 选中的机械速度真值或外部原动机速度 |
| 3 | speed_feedback；记录列32 | MotorExperiment/FeedbackStage 输出4 | rad/s / double | 机械速度反馈 |
| 4 | electrical_speed_truth；记录列38 | MotorExperiment/ElectricalSpeed 输出1 | rad/s / double | Plant电角速度 |
| 5 | electrical_speed_feedback；记录列39 | MotorExperiment/FeedbackStage 输出6 | rad/s / double | 控制器使用的电角速度 |

实际Scope块：PositionScope，纵轴：rad，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | position_reference；记录列33 | MotorExperiment/PositionCommand 输出1 | rad / double | 机械位置给定 |
| 2 | position_truth；记录列34 | MotorExperiment/MechanicalPosition 输出1 | rad / double | 选中的机械位置真值或外部原动机位置 |
| 3 | position_feedback；记录列35 | MotorExperiment/FeedbackStage 输出5 | rad / double | 机械位置反馈 |

实际Scope块：ElectricalAngleScope，纵轴：rad，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | electrical_angle_truth；记录列36 | MotorExperiment/ElectricalAngle 输出1 | rad / double | Plant真实电角度 |
| 2 | electrical_angle_feedback；记录列37 | MotorExperiment/FeedbackStage 输出3 | rad / double | 控制器使用的采样电角度 |

实际Scope块：PhaseCurrentsScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | ia_truth；记录列40 | MotorExperiment/CurrentInverseClarke 输出1 | A / double | 逆变换得到的a相对象电流 |
| 2 | ib_truth；记录列41 | MotorExperiment/CurrentInverseClarke 输出2 | A / double | 逆变换得到的b相对象电流 |
| 3 | ic_truth；记录列42 | MotorExperiment/CurrentInverseClarke 输出3 | A / double | 逆变换得到的c相对象电流 |

实际Scope块：InverterVoltagesScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | inverter_phase_voltage_abc_1；记录列43 | MotorExperiment/VoltageStage 输出8 元素1 | V / double | 逆变器支路相电压；理想旁路时不是实际施加量 |
| 2 | inverter_phase_voltage_abc_2；记录列44 | MotorExperiment/VoltageStage 输出8 元素2 | V / double | 逆变器支路相电压；理想旁路时不是实际施加量 |
| 3 | inverter_phase_voltage_abc_3；记录列45 | MotorExperiment/VoltageStage 输出8 元素3 | V / double | 逆变器支路相电压；理想旁路时不是实际施加量 |
| 4 | deadtime_error_abc_1；记录列46 | MotorExperiment/VoltageStage 输出9 元素1 | V / double | 真实电流产生的三相死区误差 |
| 5 | deadtime_error_abc_2；记录列47 | MotorExperiment/VoltageStage 输出9 元素2 | V / double | 真实电流产生的三相死区误差 |
| 6 | deadtime_error_abc_3；记录列48 | MotorExperiment/VoltageStage 输出9 元素3 | V / double | 真实电流产生的三相死区误差 |

实际Scope块：CurrentErrorScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | current_error_dq_1；记录列49 | MotorExperiment/CurrentStage 输出5 元素1 | A / double | 电流给定减反馈，元素1=d、2=q |
| 2 | current_error_dq_2；记录列50 | MotorExperiment/CurrentStage 输出5 元素2 | A / double | 电流给定减反馈，元素1=d、2=q |

实际Scope块：ControlStateScope，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | enable；记录列51 | MotorExperiment/EnableRecord 输出1 | 1 / double | 控制器使能电平 |
| 2 | reset；记录列52 | MotorExperiment/ResetRecord 输出1 | 1 / double | 同步复位电平，优先于enable |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

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
| $\omega_m$ | pmsmCfg.Speed0 | 机械rad/s | rpm乘$2\pi/60$；与电角速度通过P换算 |

### 本模块局部量

$\vartheta_{shaft}$及其fb/参考后缀表示展开机械轴位置，$\theta_r$为电角位置，$\theta_r=P\vartheta_{shaft}$。$b_{rot}$映射pmsmCfg.B，单位N·m·s/rad；不是原表$B$的N·s/m。
