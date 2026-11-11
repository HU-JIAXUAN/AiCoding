# App参数与记录

## 配置参数

默认工况的可执行入口为[mtpa_fw_app_parameters.m](mtpa_fw_app_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_mtpa_fw_model('MTPAFWMotor')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../../docs/guide/PARAMETER_USAGE.md).

| 名称 | 默认值 | 单位 | 定义/用途 |
|---|---|---|---|
| experimentCfg.SpeedReference / LoadTorque | 218 / 0.05 | rad/s / N·m | 本模块[mtpa_fw_app_parameters.m](mtpa_fw_app_parameters.m)中的App覆盖 |
| inverterCfg.Vdc | 48 | V | [inverter_parameters.m](../../../../lib/逆变器/parameter/inverter_parameters.m) |
| refCfg.FwEnable | 1 | 1 | [mtpa_fw_parameters.m](../../../../lib/MTPA弱磁/parameter/mtpa_fw_parameters.m) |

全部输入、过程量、输出及Scope的单一详细说明见[74列与十五组Scope](../../../../lib/MTPA弱磁/parameter/README.md#mtpafwmotor74列trace15组scope)。参数定义仍随其所属积木，App只组合和覆盖。

## 输入信号

速度/位置/转矩请求、负载、使能及复位由App工况产生；电流和速度反馈来自采样链。单位和来源见上述详细表。

## 过程变量

速度PI转矩和积分、分配转矩残差、MTPA/FW候选、电压需求/裕量及参考电流，均按上述74列说明记录。

## 输出信号

trace为Structure With Time，包含time及74列double数据；布尔状态记录为0/1。

## Scope 通道

SpeedScope、WeakeningCurrentsScope、WeakeningVoltagesScope、AllocationTorqueScope及其余十组Scope的实际顺序、源块、单位和数据列均列于上述详细表；本页不另复制一份通道权威。

[返回模块](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | currentCfg.Ts / refCfg.FwTs | s | 电流/分配周期与弱磁周期分别配置 |
| $R_s$ | pmsmCfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | pmsmCfg.Ld / pmsmCfg.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | pmsmCfg.Flux | Wb | 直接使用 |
| $P$ | pmsmCfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $V_{dc}$ | inverterCfg.Vdc | V | 直接使用 |

### 本模块局部量

$T_{m\_BLAC}^*$为电磁转矩请求，$T_{alloc},T_{res}$为参考分配转矩及命令残差，均为N·m；不是滞后的实际转矩。分配器局部$a_v,b_v,c_v$由共用lib维护。
