# 配置、输入、过程、输出和 Scope

默认配置由 [observer_compare_parameters.m](observer_compare_parameters.m) 返回，写入SensorObserverCompare模型工作区。以下SI参数为仿真夹具。

## 配置参数

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| pmsmCfg.Rs / Ld / Lq / Flux | 0.5 / 0.001 / 0.001 / 0.035 | Ω / H / H / Wb | 本模块覆盖SPMSM；[pmsm_parameters.m](../../../../lib/永磁同步电机/parameter/pmsm_parameters.m) |
| pmsmCfg.PolePairs / J / B | 4 / 5e-4 / 1e-4 | 1 / kg·m² / N·m·s/rad | 电气/机械转换、惯量、摩擦，原定义同上 |
| pmsmCfg.Position0 / Speed0 / Id0 / Iq0 | 0.1 / 0 / 0 / 0 | 机械rad / 机械rad/s / A / A | 电角初值0.4rad；本模块覆盖位置初值 |
| currentCfg.Ts / timingCfg.Ts / smoCfg.Ts / pllCfg.Ts | 50e-6 | s | 控制、反馈、估算同步周期 |
| currentCfg.Kpd / Kpq / Kid / Kiq / Kaw | π / π / 500π / 500π / 1000 | V/A / V/A / V/(A·s) / V/(A·s) / 1/s | 本SPMSM配置后重新计算；[current_parameters.m](../../../../lib/电流环/parameter/current_parameters.m) |
| timingCfg.FeedbackTicks / ActuationTicks | 1 / 1 | 控制拍 | 反馈年龄/执行延迟；[timing_parameters.m](../../../../lib/采样执行时序/parameter/timing_parameters.m) |
| inverterCfg.Vdc / MinDuty / PwmTs | 48 / 0.02 / 50e-6 | V / 1 / s | 平均逆变器；[inverter_parameters.m](../../../../lib/逆变器/parameter/inverter_parameters.m) |
| experimentCfg.Step / LogTs / Duration | 5e-6 / 50e-6 / 0.8 | s | Plant固定步长、日志周期、运行时间 |
| experimentCfg.Mode / UseMechanical / UseInverter / UseTiming | 1 / 1 / 1 / 1 | 1 | 速度闭环、机械对象、平均逆变器及延迟均启用 |
| experimentCfg.SpeedReference / CommandTime | 40 / 0.05 | 机械rad/s / s | 从0到40的速度给定 |
| experimentCfg.LoadTorque / LoadTime | 0.1 / 0.35 | N·m / s | 负载阶跃；负转测试方向匹配 |
| compareCfg.Direction / ObserverEnable / ObserverReset | 1 / 1 / 0 | 1 | 已知工况方向及观测器本地使能/复位，独立于原控制 |
| smoCfg.Rs / L / SlidingGain / Boundary / FilterHz | 0.5 / 0.001 / 30 / 1 / 600 | Ω / H / V / A / Hz | [smo_parameters.m](../../../../lib/观测器/滑模/parameter/smo_parameters.m)与[完整SMO参数](../../../../lib/观测器/滑模/parameter/README.md) |
| pllCfg | 共用默认，MinMagnitude=1V | 各字段SI | [PLL参数](../../../../lib/相位跟踪/parameter/README.md)，50µs；未用Plant角度初始化PLL |
| feedforwardCfg / deadtimeCfg | 原默认关闭 | 各字段SI | [FF参数](../../../../lib/电压前馈/parameter/README.md)、[死区参数](../../../../lib/死区补偿/parameter/README.md) |
| motionCfg | 原速度环设计 | 各字段SI | [速度/位置参数](../../../../lib/速度环与位置环/parameter/README.md)，本App不启用位置环 |

其余原控制字段见对应定义文件及[Sensor基线参数](../../experiment/parameter/README.md)。MAT记录保存每例全部配置。Rs偏差实验仅覆盖smoCfg，Plant不变。基础SMO只适用于Ld=Lq；原Plant默认Ld≠Lq未被改写。

## 输入信号

App没有根级Inport。ObserverMonitor的8个输入按下表顺序接入。

| 序号/名称 | 单位 | 类型 | 来源/计算或用途 |
|---|---|---|---|
| 1 phase_voltage | V，abc[3] | double | VoltageStage输出8，实际作用端电压；Clarke后采样并延迟FeedbackTicks拍 |
| 2 ia_feedback、3 ib_feedback、4 ic_feedback | A | double | FeedbackStage输出7、8、9，已采样/延迟的电流 |
| 5 theta_reference | 电角rad | double | FeedbackStage输出3，仅误差对照 |
| 6 omega_reference | 电角rad/s | double | FeedbackStage输出6，仅误差对照 |
| 7 theta_physical、8 omega_physical | 电角rad、rad/s | double | ElectricalAngle/ElectricalSpeed当前Plant状态，仅年龄核对 |

SMO的7输入为u_alpha、u_beta、i_alpha、i_beta、direction、enable、reset。前四项来自电压/电流链，后三项来自compareCfg。真实角度/速度没有在线接入SMO或PLL。

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| VoltageClarke / CurrentClarke | V / A，无状态 | 共用Clarke链接 | alpha=(2a-b-c)/3，beta=(b-c)/sqrt(3) |
| VoltageSample / VoltageAge | V / 延迟初值0 | ZOH与Delay | 50µs采样、延迟FeedbackTicks·UseTiming拍，与电流同年龄 |
| SMO.current_state / emf_state | A / V，初值0 | 共用SMO UnitDelay | 预测电流及滤波注入，算法见lib |
| ReferenceWrapped | rad，[-π,π] | sin/cos/atan2 | 将显示参考角包到与估算角相同范围 |
| AngleError / SpeedError | rad / rad/s | Sum与包角 | theta_hat−参考的包角差；omega_hat−参考的有符号差 |
| CurrentResidual / ResidualNorm | A | Sum、DotProduct、Sqrt | i_hat−i及其范数，不是电压残差 |

参考角/速度年龄为FeedbackTicks·50µs，SMO输出也属于该年龄。本对照没有把估算角外推到当前转子时刻，未来控制接入需明确外推及执行时刻。

## 输出信号

监测子系统没有Outport，以下值只进入Scope/ToWorkspace。observer_trace.signals.values为N×28，时间在observer_trace.time；MAT中records.<case>.trace列序相同。

| 列 | 名称 | 单位/类型 | 来源/用途 |
|---|---|---|---|
| 1、2 | 同年龄theta_reference、omega_reference | 电角rad、rad/s / double | theta经ReferenceWrapped，误差评价参考 |
| 3、4 | theta_physical、omega_physical | 电角rad、rad/s / double | 当前Plant状态，未送估算器 |
| 5、6、7 | theta_hat、omega_hat、valid | 电角rad、rad/s、1 / double | SMO输出1、2、3 |
| 8、9 | emf_alpha、emf_beta | V / double | SMO输出4、5 |
| 10、11 | i_hat_alpha、i_hat_beta | A / double | SMO输出6、7 |
| 12、13 | injection_alpha、injection_beta | V / double | SMO输出8、9 |
| 14、15、16 | phase_measured、emf_magnitude、phase_error | rad、V、rad / double | SMO输出10、11、12；phase_error为PLL内部误差 |
| 17、18 | measured_alpha、measured_beta | A / double | CurrentClarke |
| 19、20 | aligned_u_alpha、aligned_u_beta | V / double | VoltageAge后实际作用电压样本 |
| 21、22、23 | observer_enable、observer_reset、direction | 1 / double | compareCfg常量 |
| 24、25 | angle_error、speed_error | 电角rad、rad/s / double | 对同年龄参考的误差 |
| 26、27、28 | residual_alpha、residual_beta、residual_norm | A / double | CurrentResidual及范数 |

原trace为N×52，与[Sensor基线通道表](../../experiment/parameter/README.md)一致，模型名前缀改为SensorObserverCompare。验证用40:42的Plant相电流、43:45的实际相电压逐点核对年龄。

## Scope 通道

下表均位于ObserverMonitor，各Scope一个Mux输入，序号为实际显示顺序。

| Scope | 序号 | 名称 | 来源 | 单位/记录类型 | trace列 / 观察内容 |
|---|---|---|---|---|---|
| ObserverAngleScope | 1、2、3 | theta_reference、theta_hat、angle_error | ReferenceWrapped、SMO输出1、AngleError | rad / double | 1、5、24；参考、估算与物理角误差 |
| ObserverSpeedScope | 1、2、3 | omega_reference、omega_hat、speed_error | 参考输入、SMO输出2、SpeedError | 电角rad/s / double | 2、6、25；机械速度需除PolePairs |
| ObserverCurrentScope | 1、2 | measured_alpha、measured_beta | CurrentClarke | A / double | 17、18 |
| ObserverCurrentScope | 3、4 | i_hat_alpha、i_hat_beta | SMO输出6、7 | A / double | 10、11 |
| ObserverCurrentScope | 5、6 | residual_alpha、residual_beta | CurrentResidual | A / double | 26、27；非控制电流误差 |
| ObserverEmfScope | 1、2、3 | emf_alpha、emf_beta、emf_magnitude | SMO输出4、5、11 | V / double | 8、9、15；幅值与valid门限 |
| ObserverStatusScope | 1、2、3、4 | valid、observer_enable、observer_reset、direction | SMO输出3、compareCfg常量 | 1 / double | 7、21、22、23 |
| ObserverVoltageScope | 1、2 | aligned_u_alpha、aligned_u_beta | VoltageAge输出 | V / double | 19、20；实际电压年龄 |

仅记录未送入新Scope的列为3/4、12/13、14、16、28；不要当作已有Scope额外通道。根层原11组Scope名称/顺序沿用[基线参数页](../../experiment/parameter/README.md#scope-通道)，包括电流、电压、占空比、转矩、速度、位置、角度、三相电流、逆变器电压、电流误差及控制状态，本App没有改接这些通道。

[模块入口](../README.md) · [运行与调参](../build_process/USAGE.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | currentCfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | pmsmCfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d=L_q$ | smoCfg.L / pmsmCfg.Ld / pmsmCfg.Lq | H | SPMSM公共电感；原表mH乘$10^{-3}$，局部符号$\ell_{sp}$ |
| $\psi_m$ | pmsmCfg.Flux | Wb | 直接使用 |
| $P$ | pmsmCfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | AngleTracking/PLL输出1；pllCfg.Theta0给定初始状态 | 电角rad | 这里PLL的输入已构造成转子电相位 |
| $\hat\omega_r$ | AngleTracking/PLL输出2 | 电角rad/s | 机械rad/s乘P得到电角rad/s；估计机械速度为本输出除P |

### 本模块局部量

$\theta_{r,ref}$是同年龄的真实电角参考，$\hat\theta_r$是观测估角；两者只在评分分支比较。$\ell_{sp}=L_d=L_q$为本SPMSM公共电感，工程smoCfg.L使用H。
