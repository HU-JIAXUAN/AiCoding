# HFI轴线波形与分析

R2026b连续轴线30项MIL、正交探针27项物理MIL，共57项组件MIL；包含拒绝资格和π歧义反例，不表示57个可用工作点。轴线本次30项在隔离副本通过并按SHA256输出，正式路径默认运行一致；探针未修改算法并复跑名义/默认检查。物理PMSM14项和HFI启动App22项另计。

| 文件 | 内容 |
|---|---|
| [ANALYSIS.md](ANALYSIS.md) | 工况、指标窗口、采样年龄、噪声和算法限制 |
| [run_hfi_axis_validation.m](run_hfi_axis_validation.m) | 30项独立MIL，含6项外部均值校准/失效检查 |
| `axis_results.mat`（运行验证后生成） | 每项时间、38列trace、参数、输入及报告；旧37列保持 |
| [axis_metrics.json](axis_metrics.json) | 逐项数值和通过/失败状态 |
| [axis_verification.json](axis_verification.json) | 正式路径、嵌入源码一致性、默认运行和Scope列索引 |
| [plot_hfi_axis_results.m](plot_hfi_axis_results.m) | 从已保存数据导出图 |
| [轴线跟踪](axis_tracking.svg) | 自由物理对象、π等价/完整角误差及响应 |
| [π歧义](axis_pi_ambiguity.svg) | 轴线锁定但完整角差π |
| [采样年龄](axis_sample_age.svg) | 无延迟、错配、年龄对齐 |
| [ADC对照](axis_adc.svg) | 相电流、滤波开/关的轴误差和资格 |
| [PROBE_ANALYSIS.md](PROBE_ANALYSIS.md) | 正交张量、圆转子拒绝、运动快照与边界 |
| [run_hfi_probe_validation.m](run_hfi_probe_validation.m) | 27项探针物理MIL |
| `probe_results.mat`（运行验证后生成） | 探针逐项输入、参数和38列波形 |
| [probe_metrics.json](probe_metrics.json) | 逐项指标 |
| [probe_verification.json](probe_verification.json) | 受测/输出哈希、正式路径及旧HFI一致性 |
| [张量](probe_tensor.svg)、[圆转子](probe_isotropic.svg)、[ADC](probe_adc.svg) | 探针实际数据图 |

同名PNG用于预览，SVG用于导出。运行默认模型的方法见[USAGE](../build_process/USAGE.md)，Scope顺序见[参数页](../parameter/README.md)。

[模块入口](../README.md)
