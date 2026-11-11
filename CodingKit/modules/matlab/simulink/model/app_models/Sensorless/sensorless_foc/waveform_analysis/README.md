# 波形与分析

[run_sensorless_foc_validation.m](run_sensorless_foc_validation.m)执行物理PMSM模型的起转、接管、稳态、失效与反例工况；[read_sensorless_foc_result.m](read_sensorless_foc_result.m)统一读取四组日志并核对采样时间、有限值及列宽。

| 文件 | 内容 |
|---|---|
| [metrics.json](metrics.json) | 实际通过状态和每个工况的数值指标 |
| `results.mat`（运行验证后生成） | 每个工况的实际参数、六列输入、四组原始数据和报告 |
| [ANALYSIS.md](ANALYSIS.md) | 工况、计算窗口、结果与证据边界 |

正转、反转、观测器失效和电流对齐反例波形由验证脚本输出同名PNG/SVG。波形读取及Scope说明见[参数页](../parameter/README.md)。

EEMF和Flux各新增8项物理MIL。[OBSERVER_ANALYSIS.md](OBSERVER_ANALYSIS.md)列出全部指标、计算窗口和证据范围；[eemf_metrics.json](eemf_metrics.json)/[flux_metrics.json](flux_metrics.json)与对应results.mat保存实测数据，各有正转、反转、失效三组PNG/SVG。[重建与正式路径校验](observer_foc_verification.json)绑定源文件和输出。入口为[run_observer_foc_validation.m](run_observer_foc_validation.m)，返回日志由[read_observer_foc_result.m](read_observer_foc_result.m)按实际列定义解码。

[模块入口](../README.md)

新增[FlyingFluxFOC分析](FLYING_ANALYSIS.md)：[13项物理MIL](flying_results.json)、[8组逻辑/代数检查](flying_logic_checks.json)和[校验记录](flying_verification.json)。入口为[run_flying_foc_validation.m](run_flying_foc_validation.m)、[run_flying_logic_checks.m](run_flying_logic_checks.m)和[plot_flying_foc_results.m](plot_flying_foc_results.m)，每个工况保存`flying_*.mat`，三组PNG/SVG分别记录捕获、失锁续流和高速被动整流。

扩展观测App：[40项分析](EXTENSION_ANALYSIS.md)、[验证入口](run_extension_foc_validation.m)、[分析函数](analyze_extension_foc.m)、[绘图](export_extension_foc_plots.m)。mras/ekf/ukf/sigmoid各10份原始MAT和results.json；[重建](extension_rebuild_verification.json)、[M源](extension_rebuild_m_sources.json)、[Code Analyzer](extension_code_analysis.json)分别登记；各算法native_inventory.json与extension_layout_equivalence.json记录真实通道/连接及六组轨迹一致性；[最终校验记录](extension_verification.json)绑定40项数据、14M重建及四模型正式路径默认重放。
