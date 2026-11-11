# 无位置传感器MTPA与弱磁FOC

## 用途

`SensorlessFieldWeakeningFOC.slx`将凸极IPMSM、EEMF、PLL、启动/接管、电流环和MTPA/弱磁分配器组装成可运行App。物理对象由占空比和实际母线共同驱动；观测器读取实际端电压与电流，真实角度只供对象内部与离线评估使用。模型使用R2026b，默认从静止起转至210机械rad/s。

它是已建lib的完整装配，20个库链接保持共用。旋转中复位、重新使能和方向改变先关断并重新观察；本App不执行高速带速接管，低观测EMF后才允许重新对齐。已有[磁链带速App](../sensorless_foc/build_process/FLYING_USAGE.md)负责另一个适用边界。这里没有有限母线电容状态。

## 文件

| 路径 | 状态 |
|---|---|
| [src/SensorlessFieldWeakeningFOC.slx](src/SensorlessFieldWeakeningFOC.slx) | 已创建 |
| [src/README.md](src/README.md) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [parameter/sensorless_fw_parameters.m](parameter/sensorless_fw_parameters.m) | 已创建 |
| [build_process/README.md](build_process/README.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/README.md](waveform_analysis/README.md) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| [ref/README.md](ref/README.md) | 已创建 |
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |

## 接口

App根图没有外部Inport/Outport；以下是M运行器与模型工作区之间的数据接口。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| testStim：速度、负载、使能、复位、方向、观测器使能、实际母线 | 输入 | 逐列SI/标志 | Structure With Time，7列double | 50μs |
| plant_trace | 输出 | 逐列SI/状态 | 36列double | 5μs |
| observer_trace / controller_trace | 输出 | 逐列SI/状态 | 20 / 46列double | 50μs |
| allocation_trace / actuation_trace / guard_trace | 输出 | 逐列SI/状态 | 25 / 27 / 9列double | 50μs |

输入、过程状态、日志列号与29组Scope的实际通道在[参数说明](parameter/README.md)。分配器内部标志为boolean，入日志Mux前显式转成double。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| pmsmCfg / currentCfg / emfCfg / pllCfg | 逐字段SI | [sensorless_fw_parameters.m](parameter/sensorless_fw_parameters.m) |
| refCfg：MTPA表、电流圆、弱磁、速度环 | 逐字段SI | [sensorless_fw_parameters.m](parameter/sensorless_fw_parameters.m) |
| fwCfg / startGuardCfg / focCfg / experimentCfg | s、V、SI及标志 | [sensorless_fw_parameters.m](parameter/sensorless_fw_parameters.m) |
| 验收阈值及16项工况 | 逐字段SI | [阈值](parameter/sensorless_fw_validation_parameters.m)、[核心](parameter/sensorless_fw_case_definitions.m)、[边界](parameter/sensorless_fw_edge_cases.m) |

先调用参数入口，再修改返回结构并调用`refresh_sensorless_fw_parameters`；运行器通过SimulationInput覆盖本次仿真。默认值修改后重新初始化会写入本模型工作区。[运行方法](build_process/USAGE.md)给出完整命令。

## 验证

[核心验证](waveform_analysis/run_sensorless_fw_validation.m)7项和[边界验证](waveform_analysis/run_sensorless_fw_edges.m)9项通过，共14项正常/限制/拒绝检查与2项明确反例。默认末0.3s速度约210rad/s、角误差RMS约0.02597电角rad、物理d电流约−5.910A；正反向回馈母线功率约−106.879W。

记录见[核心JSON](waveform_analysis/guarded_core/fw_core_results.json)、[边界重分析JSON](waveform_analysis/edges/edge_reanalysis_results.json)、[原生结构/Scope](waveform_analysis/fw_native_inventory.json)、[布局前后六组轨迹一致](waveform_analysis/fw_final_layout_equivalence.json)和[波形分析](waveform_analysis/ANALYSIS.md)。原始错误末速度判据的边界报告保留，当前结论使用重分析记录。[完整验证记录](waveform_analysis/fw_verification.json)确认只凭M重建及正式路径默认重放的六组完整数据均逐点差0；17份本地M已做Code Analyzer检查，保留构建脚本的数组增长等建议。原有359份M/SLX字节未变。

[Sensorless入口](../README.md) · [目录规则](../../../../rules.md)
