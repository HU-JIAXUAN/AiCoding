# dq 电流 PI 与电压限制：参数与信号

新增FrameTrackingPI与FrameTrackingPITest的配置、7输入/3输出、8状态、30列数据和6组Scope分别登记于[FRAME_TRACKING.md](FRAME_TRACKING.md)。新测试默认50µs；以下原CurrentLoopTest继续100µs。

## 配置参数

默认工况的可执行入口为[current_loop_test_parameters.m](current_loop_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('CurrentLoopTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md). FrameTrackingPITest另用[frame_pi_test_parameters.m](frame_pi_test_parameters.m)配置十列默认输入。

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| currentCfg.Ts | 0.0001 | s | 本模块更新周期；[current_parameters.m](current_parameters.m) |
| currentCfg.BandwidthHz | 500 | Hz | 电流PI设计带宽起点；[current_parameters.m](current_parameters.m) |
| currentCfg.Kpd | 3.1415927 | V/A | d轴比例增益，Ld·2πfc；[current_parameters.m](current_parameters.m) |
| currentCfg.Kpq | 3.7699112 | V/A | q轴比例增益，Lq·2πfc；[current_parameters.m](current_parameters.m) |
| currentCfg.Kid | 1570.7963 | V/(A·s) | d轴积分增益，Rs·2πfc，未乘Ts；[current_parameters.m](current_parameters.m) |
| currentCfg.Kiq | 1570.7963 | V/(A·s) | q轴积分增益，未乘Ts；[current_parameters.m](current_parameters.m) |
| currentCfg.Kaw | 1000 | 1/s | 回算增益，0关闭回算；[current_parameters.m](current_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| TrackingPI.error_dq | A，[d;q] | double[2] | 100µs；功能见搭建步骤 |
| TrackingPI.voltage_residual | V，[d;q] | double[2] | 100µs；功能见搭建步骤 |
| TrackingPI.enable / reset | 1 | boolean兼容 | 100µs；功能见搭建步骤 |
| VoltageLimit.voltage_request | V，[d;q] | double[2] | 继承；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | id_ref | A |
| 2 | iq_ref | A |
| 3 | omega_e | rad/s |
| 4 | enable | 逻辑兼容double |
| 5 | reset | 逻辑兼容double |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| IntegralMemory | V，[0;0] | UnitDelay | 上一拍积分贡献 |
| IntegralDerivative | V/s | Ki·e+Kaw·r | 积分与回算 |
| UnboundedVoltage | V | Kp·e+x | PI自身电压 |
| Magnitude / LimitFraction | V / 1 | VoltageLimit | 圆限制幅值与系数 |
| voltage_residual | V | 可行命令减总请求 | 同一拍和同一评价点 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| TrackingPI.voltage_pi / integral_state | V，[d;q] | double[2] | 100µs |
| VoltageLimit.voltage_limited / scale | V[2] / 1 | double | 继承 |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道

另有下列数据仅进入ToWorkspace，没有送入Scope：

| 记录列 | 名称 | 单位 | 含义 |
|---|---|---|---|
| 15 | omega_e | rad/s | 电角速度，不能与机械速度混用 |


### CurrentLoopTest

实际Scope块：Currents，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id_reference；记录列1 | CurrentLoopTest/InputChannels 输出1 | A / double | d轴电流给定 |
| 2 | iq_reference；记录列2 | CurrentLoopTest/InputChannels 输出2 | A / double | q轴电流给定 |
| 3 | id；记录列3 | CurrentLoopTest/Electrical 输出1 | A / double | d轴电流 |
| 4 | iq；记录列4 | CurrentLoopTest/Electrical 输出2 | A / double | q轴电流 |

实际Scope块：Voltages，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | vpi_dq_1；记录列5 | CurrentLoopTest/CurrentPI 输出1 元素1 | V / double | PI自身电压，元素1=d、2=q |
| 2 | vpi_dq_2；记录列6 | CurrentLoopTest/CurrentPI 输出1 元素2 | V / double | PI自身电压，元素1=d、2=q |
| 3 | voltage_dq_1；记录列7 | CurrentLoopTest/VoltageLimit 输出1 元素1 | V / double | 圆限制后的电压，元素1=d、2=q |
| 4 | voltage_dq_2；记录列8 | CurrentLoopTest/VoltageLimit 输出1 元素2 | V / double | 圆限制后的电压，元素1=d、2=q |
| 5 | integral_dq_1；记录列9 | CurrentLoopTest/CurrentPI 输出2 元素1 | V / double | PI积分贡献，元素1=d、2=q |
| 6 | integral_dq_2；记录列10 | CurrentLoopTest/CurrentPI 输出2 元素2 | V / double | PI积分贡献，元素1=d、2=q |
| 7 | residual_dq_1；记录列11 | CurrentLoopTest/VoltageResidual 输出1 元素1 | V / double | 电压限制残差，元素1=d、2=q |
| 8 | residual_dq_2；记录列12 | CurrentLoopTest/VoltageResidual 输出1 元素2 | V / double | 电压限制残差，元素1=d、2=q |

实际Scope块：Limit，纵轴：1，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | limit_scale；记录列13 | CurrentLoopTest/VoltageLimit 输出2 | 1 / double | 圆限制系数，1表示未触及圆限制 |
| 2 | enable；记录列16 | CurrentLoopTest/InputChannels 输出4 | 1 / double | 控制器使能电平 |
| 3 | reset；记录列17 | CurrentLoopTest/InputChannels 输出5 | 1 / double | 同步复位电平，优先于enable |

实际Scope块：Torque，纵轴：N*m，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | torque；记录列14 | CurrentLoopTest/Electrical 输出3 | N*m / double | 电磁转矩 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。CurrentPIProbeTest没有Scope。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | motor.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | motor.Ld / motor.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |

### 本模块局部量

单轴设计中的$\ell_{axis}$分别取$L_d,L_q$；工程motor.Ld/Lq使用H。$\omega_c=2\pi\,BandwidthHz$为电流环设计角频率。积分状态、误差向量和坐标变换矩阵按本模块公式单独定义。
