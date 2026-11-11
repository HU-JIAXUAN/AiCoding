# 高频注入轴线观测器

## 用途

按主要参考书4.2–4.3实现脉振方波HFI和双角PLL，并按8.2组装双脉冲极性。SaliencyProbe独立拟合实际逆电感张量、拒绝无凸极工况；HFIAxis可使用实测均值；PolarityPulse独立管理等待、双脉冲、实际伏秒、峰值和故障。App只通过库链接组装，真实角度仅评分。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/HighFrequencyObserver.slx](src/HighFrequencyObserver.slx) | 已创建 |
| [src/HFIAxisTest.slx](src/HFIAxisTest.slx) | 已创建 |
| [src/HFISaliencyTest.slx](src/HFISaliencyTest.slx) | 已创建 |
| [src/hfi_probe_update.m](src/hfi_probe_update.m) | 已创建 |
| [src/hfi_probe_output.m](src/hfi_probe_output.m) | 已创建 |
| [src/hfi_demodulate.m](src/hfi_demodulate.m) | 已创建 |
| [src/hfi_track_axis.m](src/hfi_track_axis.m) | 已创建 |
| [parameter/hfi_parameters.m](parameter/hfi_parameters.m) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |

[模型](src/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md) · [参数](parameter/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha/u_beta、i_alpha/i_beta | 输入 | V、A | double | 50 μs |
| injection_scale、enable、reset | 输入 | 1、逻辑 | double兼容 | 50 μs |
| injection_alpha/beta | 输出 | V | double | 50 μs |
| theta_axis、omega_axis、axis_valid | 输出 | 电角rad、rad/s、0/1 | double | 50 μs |
| 双角相位/误差、响应幅值/逆电感、实际电压差、响应资格、载波、锁定计数 | 输出 | 见参数表 | double | 50 μs |

HFIAxis为8入15出、10组Scope和38列trace，见[完整接口表](parameter/README.md)；SaliencyProbe为6入16出、7组Scope和38列trace，见[探针参数](parameter/PROBE_PARAMETERS.md)；PolarityPulse为10入16出，见[极性参数/状态](parameter/POLARITY_PARAMETERS.md)。轴线自身仍只确定到π，不直接放行完整位置。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 周期、电感、注入、解调低通和响应门限 | SI | [hfi_parameters.m](parameter/hfi_parameters.m) |
| 双角PLL | SI | [hfi_pll_parameters.m](parameter/hfi_pll_parameters.m) |
| 测试时长、ADC和延迟工况 | SI | [hfi_test_parameters.m](parameter/hfi_test_parameters.m) |
| 物理电机实例 | SI | [hfi_plant_parameters.m](parameter/hfi_plant_parameters.m) |
| 正交探针激励、窗口和资格 | SI | [hfi_probe_parameters.m](parameter/hfi_probe_parameters.m) |
| 双脉冲时长、峰值、剂量和退出 | SI | [hfi_polarity_parameters.m](parameter/hfi_polarity_parameters.m) |
| 探针测试工况 | SI | [hfi_probe_test_parameters.m](parameter/hfi_probe_test_parameters.m) |

`initialize_hfi_test('HFIAxisTest')`重载默认参数；单次实验用SimulationInput，不改SLX数值。参数改动和Scope观察方法见[USAGE](build_process/USAGE.md)。

## 验证

R2026b轴线30项独立MIL通过（原24项加实测均值6项）；原24项前37列与旧结果完全一致。新一轮在隔离副本运行，受测SLX/M源和结果按SHA256输出，正式路径默认运行核对一致。物理对象14项另计。

[验证脚本](waveform_analysis/run_hfi_axis_validation.m) · `axis_results.mat`（运行验证后生成） · [逐项指标](waveform_analysis/axis_metrics.json) · [正式路径核对](waveform_analysis/axis_verification.json) · [分析](waveform_analysis/ANALYSIS.md)

SaliencyProbe原27项独立物理MIL继续有效；本次其内部System XML及算法源码不变，并复跑旧名义工况与默认路径检查。本模块合计3个SLX、57项轴线/探针MIL；PolarityPulse另在[HFI启动App](../../../app_models/Sensorless/sensorless_hfi/README.md)完成22项物理组合MIL，不重复计入独立lib测试。见[探针分析](waveform_analysis/PROBE_ANALYSIS.md)、[极性搭建](build_process/POLARITY_BUILD.md)及[参数](parameter/POLARITY_PARAMETERS.md)。

已实现探针快照均值接入及双脉冲完整位置资格；快照不是在线连续辨识。[HFI低速FOC](../../../app_models/Sensorless/sensorless_hfi/waveform_analysis/FOC_ANALYSIS.md)另完成24项物理MIL；HFI↔基波双向融合、single/SIL及C2000验证继续建设。
