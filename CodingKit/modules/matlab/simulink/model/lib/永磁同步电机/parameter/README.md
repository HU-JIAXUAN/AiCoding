# PMSM 数学电机与刚性负载：参数与信号

高频/饱和对象另见[HF_PARAMETERS.md](HF_PARAMETERS.md)，包含可执行M文件入口、增量电感/饱和参数、十个输出、13列trace和六组实际Scope。原模型参数在本页保留。

## 配置参数

新增运行时母线的可执行入口为[bridge_bus_test_parameters.m](bridge_bus_test_parameters.m)，加载后用`initialize_bridge_bus_test('PMSMBridgeBusPlantTest')`重读；[BRIDGE_BUS_PARAMETERS.md](BRIDGE_BUS_PARAMETERS.md)说明4输入、过程参数、34列日志和九组Scope。实际母线由BusTimes/BusValues或第四输入给出，名义bridgeCfg.Vdc每拍被覆盖。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $V_{dc}$ | bus_voltage / bridgeTestCfg.BusValues | V | 直接使用原书V单位 |
| $i_{dc}$ | dc_current | A | 直接使用，负值回馈 |
| $\theta_r$ | theta_e | 电角rad | 直接使用；不是Position0机械rad |
| $P$ | bridgeCfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |

默认工况的可执行入口为[pmsm_test_parameters.m](pmsm_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('PMSMPlantTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| pmsmCfg.Rs | 0.5 | Ω | 每相电阻；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Ld | 0.001 | H | d轴电感；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Lq | 0.0012 | H | q轴电感；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Flux | 0.035 | Wb | 永磁磁链；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.PolePairs | 4 | 1 | 极对数；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.J | 0.0005 | kg·m² | 电机与刚性负载总惯量；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.B | 0.0001 | N·m·s/rad | 黏性阻尼；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Id0 | 0 | A | 初始d电流；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Iq0 | 0 | A | 初始q电流；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Speed0 | 0 | rad/s | 初始机械速度；[pmsm_parameters.m](pmsm_parameters.m) |
| pmsmCfg.Position0 | 0 | rad | 初始机械位置；[pmsm_parameters.m](pmsm_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| Electrical.vd / vq | V | double | 连续；功能见搭建步骤 |
| Electrical.omega_e | rad/s，电角速度 | double | 连续；功能见搭建步骤 |
| Mechanical.torque / load_torque | N·m，有符号 | double | 连续；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | vd | V |
| 2 | vq | V |
| 3 | omega_e | rad/s |
| 4 | Te_external | N·m |
| 5 | Tl | N·m |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| IdState / IqState | A；初始0 | Integrator | 电压平衡除以电感后的积分 |
| DVoltageBalance / QVoltageBalance | V | Sum | 电感等效电压 |
| TorqueFlux | Wb | Flux+(Ld−Lq)·id | 永磁与磁阻转矩 |
| SpeedState / PositionState | rad/s、rad；初始0 | Mechanical Integrator | 机械状态 |
| WrapAngle | rad，0到2π | mod(p·theta_m,2π) | 电角度包裹 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| Electrical.id / iq | A，相峰值 | double | 连续 |
| Electrical.torque | N·m | double | 连续 |
| Mechanical.omega_m / omega_e | rad/s，机械/电 | double | 连续 |
| Mechanical.theta_m / theta_e | rad，机械展开/电角包裹 | double | 连续 |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道

另有下列数据仅进入ToWorkspace，没有送入Scope：

| 记录列 | 名称 | 单位 | 含义 |
|---|---|---|---|
| 3 | omega_e_imposed | rad/s | 独立电气台架的外部电角速度 |


### PMSMPlantTest

实际Scope块：Currents，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id；记录列6 | PMSMPlantTest/Electrical 输出1 | A / double | d轴电流 |
| 2 | iq；记录列7 | PMSMPlantTest/Electrical 输出2 | A / double | q轴电流 |

实际Scope块：Torques，纵轴：N*m，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | mechanical_torque_input；记录列4 | PMSMPlantTest/InputChannels 输出4 | N*m / double | 独立机械台架转矩输入，和电磁转矩分开 |
| 2 | load_torque；记录列5 | PMSMPlantTest/InputChannels 输出5 | N*m / double | 有符号负载，进入Te−Tl−Bω |
| 3 | electromagnetic_torque；记录列8 | PMSMPlantTest/Electrical 输出3 | N*m / double | 电气方程计算的电磁转矩 |

实际Scope块：Speed，纵轴：rad/s，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | omega_m；记录列9 | PMSMPlantTest/Mechanical 输出1 | rad/s / double | 机械速度 |
| 2 | omega_e_mechanical；记录列12 | PMSMPlantTest/Mechanical 输出4 | rad/s / double | 机械部分输出的电角速度 |

实际Scope块：Position，纵轴：rad，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | theta_m；记录列10 | PMSMPlantTest/Mechanical 输出2 | rad / double | 展开机械位置 |
| 2 | theta_e；记录列11 | PMSMPlantTest/Mechanical 输出3 | rad / double | 包角电角度 |

实际Scope块：Voltage，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | vd；记录列1 | PMSMPlantTest/InputChannels 输出1 | V / double | d轴施加电压 |
| 2 | vq；记录列2 | PMSMPlantTest/InputChannels 输出2 | V / double | q轴施加电压 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

四状态SPMSM估计过程另见[SENSORLESS_PARAMETERS.md](SENSORLESS_PARAMETERS.md)和[pmsm_sensorless_parameters.m](pmsm_sensorless_parameters.m)，说明状态、单L来源、过程/测量输出及独立9列输入。本过程M没有Scope；估计器Scope随各模块维护。

桥耦合对象另见[BRIDGE_PARAMETERS.md](BRIDGE_PARAMETERS.md)，包括21个物理/数值配置字段、验证工况、四状态、16个输出、33列记录及七组Scope；入口为[pmsm_bridge_parameters.m](pmsm_bridge_parameters.m)和[bridge_test_parameters.m](bridge_test_parameters.m)。修改后调用initialize_bridge_test重新加载，单次覆盖使用run_bridge_case。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | pmsm_bridge_parameters返回cfg.Ts / pmsm_sensorless_parameters返回cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | cfg.Ld / cfg.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | cfg.Flux | Wb | 直接使用 |
| $P$ | cfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\omega_m$ | cfg.Speed0 | 机械rad/s | rpm乘$2\pi/60$；与电角速度通过P换算 |
| $J$ | cfg.J（pmsm_parameters工厂） | kg·m² | 直接使用 |
| $L_{dq}=L_{qd}$ | cfg.CrossInductance（pmsm_hf_parameters工厂） | H | 原表mH乘$10^{-3}$；本模型常交叉项同时给出相同增量值 |

### 本模块局部量

$\vartheta_{shaft}$是展开机械轴位置，$b_{rot}$是旋转黏性阻尼；分别映射Position0/机械位置状态、B。原表$\theta_m$为交叉饱和角，$B$单位N·s/m，不直接换算为上述旋转量。$\ell_{sp}=L_d=L_q$只用于SPMSM估计过程；$\mathbf M$是桥后向方程矩阵。CrossInductance对应$L_{dq}=L_{qd}$；本模型常交叉项的增量值也相同。
