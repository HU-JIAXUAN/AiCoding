# 有位置闭环中的观测器并行对照

## 用途

SL03的Sensor对照App。由现有MotorExperiment装配扩展，控制继续使用仿真位置反馈；新增ObserverMonitor只有输入端口，没有输出回到控制器。内部通过库链接复用基础SPMSM SMO、PLL和Clarke变换，不保存观测器算法副本。

本模块默认Ld=Lq=1mH，作为明确的SPMSM工况；没有修改通用Plant的原Ld≠Lq默认值。实际作用相电压与采样电流按相同反馈年龄送入SMO，角度/速度误差也与该年龄的参考比较。它是无位置接管之前的对照，仍归Sensor。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SensorObserverCompare.slx](src/SensorObserverCompare.slx) | 已创建 |
| [parameter/observer_compare_parameters.m](parameter/observer_compare_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/build_observer_compare.m](build_process/build_observer_compare.m) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_observer_compare_validation.m](waveform_analysis/run_observer_compare_validation.m) | 已创建 |

[模型](src/README.md) · [搭建过程](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

App根层无外部Inport/Outport，工况由本地配置和Step源产生。下表列内部监测子系统输入及记录输出，非新公共Bus。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| ObserverMonitor.phase_voltage | 内部输入 | V，[a;b;c] | double[3] | 从执行链采样50µs |
| ia_feedback / ib_feedback / ic_feedback | 内部输入 | A | double | 50µs，含FeedbackTicks年龄 |
| theta_reference / omega_reference | 内部输入，仅误差对照 | 电角rad / rad/s | double | 与采样电流同年龄 |
| theta_physical / omega_physical | 内部输入，仅年龄核对 | 电角rad / rad/s | double | 连续Plant，记录50µs |
| theta_e_hat / omega_e_hat / valid | 记录输出 | 电角rad / rad/s / 1 | double | 50µs |
| observer_trace / trace | 记录输出 | 逐列SI | double[28] / double[52] | 50µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| p.* 各模块配置与App工况 | SI，见参数页 | [observer_compare_parameters.m](parameter/observer_compare_parameters.m) |
| compareCfg.Direction / ObserverEnable / ObserverReset | 1 | 同上 |
| smoCfg / pllCfg | SI | 同上引用共用lib参数，保留独立于Plant的估算器配置 |

## 验证

R2026b下8/8项完整PMSM MIL通过，包含正反转、0/1/2拍反馈年龄、Rs偏差、观测器禁能/复位和强制转速对照。见[分析](waveform_analysis/ANALYSIS.md)、`results.mat`（运行验证后生成）、[指标](waveform_analysis/metrics.json)。正常工况最后0.2s角度RMS约0.00136–0.00162rad，参考/电压/电流年龄逐点核对通过。改变或禁能/复位观测器时原52列控制数据差为0。未执行无位置接管、single、SIL或硬件。

[Sensor分类](../README.md) · [无位置建设计划](../../../../docs/plans/SENSORLESS_PLAN.md)
