# dq 解耦与反电势前馈：参数与信号

## 配置参数

默认工况的可执行入口为[feedforward_test_parameters.m](feedforward_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_motor_model('FeedforwardTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| feedforwardCfg.Enable | 0 | 1 | 功能/控制器使能；不等同门极停机；[feedforward_parameters.m](feedforward_parameters.m) |
| feedforwardCfg.ParameterScale | 1 | 1 | 前馈模型Ld/Lq/Flux缩放；[feedforward_parameters.m](feedforward_parameters.m) |

参数为自定义仿真夹具。独立FeedforwardTest加载时Enable=1，DeadtimeTest加载时模型和补偿开关均为1；整机默认关闭FF与死区。

引用其他模块的原定义：[电机](../../永磁同步电机/parameter/pmsm_parameters.m)、[逆变器](../../逆变器/parameter/inverter_parameters.m)、[时序](../../采样执行时序/parameter/timing_parameters.m)、[整机Scope](../../../app_models/Sensor/experiment/parameter/README.md)。不另存顶层参数副本。

## 输入信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| Feedforward.id / iq | A，反馈电流 | double | 100µs；功能见搭建步骤 |
| Feedforward.omega_e | rad/s，电角速度 | double | 100µs；功能见搭建步骤 |

测试输入testStim.signals.values列顺序如下。testStim.time=[]表示按FromWorkspace的SampleTime逐行读取，没有额外时间列。

| 列 | 名称 | 单位/类型 |
|---|---|---|
| 1 | id | A |
| 2 | iq | A |
| 3 | omega_e | rad/s |

## 过程变量

| 名称 | 单位/状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| NegativeQFlux | Wb | −Lq·iq·ParameterScale | d轴补偿磁链 |
| TotalDFlux | Wb | (Ld·id+Flux)·ParameterScale | q轴补偿磁链 |
| vd_ff / vq_ff | V | 电角速度乘磁链 | 不能用机械速度直接代入 |
| EnabledFeedforward | V[2] | 整机Active门控 | 禁能/复位置零 |
| ConsistentResidual | V[2] | 可行命令减总请求 | 正常前馈不应产生虚假饱和 |

## 输出信号

| 名称 | 单位 | 类型 | 周期/用途 |
|---|---|---|---|
| Feedforward.vd_ff / vq_ff | V | double | 100µs |

向量2元素为d/q、3元素为a/b/c；记录按元素展开。记录全部为double，桥臂门极在记录前由boolean显式转换。

## Scope 通道


### FeedforwardTest

实际Scope块：CurrentsScope，纵轴：A，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | id；记录列1 | FeedforwardTest/InputChannels 输出1 | A / double | d轴电流 |
| 2 | iq；记录列2 | FeedforwardTest/InputChannels 输出2 | A / double | q轴电流 |

实际Scope块：ElectricalSpeedScope，纵轴：rad/s，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | omega_e；记录列3 | FeedforwardTest/InputChannels 输出3 | rad/s / double | 电角速度，不能与机械速度混用 |

实际Scope块：FeedforwardVoltageScope，纵轴：V，图例已开启。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | vd_ff；记录列4 | FeedforwardTest/Feedforward 输出1 | V / double | d轴耦合补偿电压 |
| 2 | vq_ff；记录列5 | FeedforwardTest/Feedforward 输出2 | V / double | q轴耦合与反电势前馈 |


记录列对应out.trace.signals.values(:,列号)，时间在out.trace.time。批量运行后Scope显示最后一个case；比较请加载results.mat中的指定case。自动缩放时要结合单位和误差容差读图。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $R_s$ | pmsmCfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | pmsmCfg.Ld / pmsmCfg.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | pmsmCfg.Flux | Wb | 直接使用 |

### 本模块局部量

$\ell_{axis}$表示正在讨论的d或q轴电感，实际两轴使用$L_d,L_q$，不是原表BLDC相自感$L$。工程omega_e输入对应$\omega_r$，估计反馈时对应$\hat\omega_r$。
