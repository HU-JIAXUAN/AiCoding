# 波形与验证记录

[ANALYSIS.md](ANALYSIS.md)解释默认弱磁、母线阶跃、四象限、不可达参考、重启和互锁反例。核心7项与边界9项共16项，其中2项为明确反例，不算作正常工况通过。

| 文件/目录 | 内容 |
|---|---|
| [run_sensorless_fw_validation.m](run_sensorless_fw_validation.m) | 核心7项，逐项保存参数、输入、原始数据、指标 |
| [run_sensorless_fw_edges.m](run_sensorless_fw_edges.m) | 9项事件/拒绝/互锁检查；支持同数据重分析 |
| [analyze_sensorless_fw_case.m](analyze_sensorless_fw_case.m) | 包角误差、真实电流、可行性、功率和尾段统计 |
| [export_sensorless_fw_plots.m](export_sensorless_fw_plots.m) | 从保留MAT重建PNG/SVG |
| [guarded_core/fw_core_results.json](guarded_core/fw_core_results.json) | 当前互锁版本核心结果 |
| [guarded_core/guard_bypass_equivalence.json](guarded_core/guard_bypass_equivalence.json) | 绕过互锁时与原版五组轨迹差0 |
| [edges/edge_results.json](edges/edge_results.json) | 首次使用错误末速度判据的报告，保留供追溯 |
| [edges/edge_reanalysis_results.json](edges/edge_reanalysis_results.json) | 同原始数据的机械连续性重分析，9项通过 |
| [fw_native_inventory.json](fw_native_inventory.json) | 原生连接、20链接、29Scope、实际端口宽度 |
| [fw_final_layout_equivalence.json](fw_final_layout_equivalence.json) | 布局前后六组数据差0 |
| [fw_parameter_snapshot.json](fw_parameter_snapshot.json) | 本次参数与日志定义快照，不代替可执行参数入口 |
| [fw_verification.json](fw_verification.json) | 16项检查、M重建、正式重放与原359份源保护 |
| [fw_code_analysis.json](fw_code_analysis.json) | 17份M静态检查，保留非语法建议 |
| `fresh_default.mat`（运行验证后生成） | 独立M重建的六组完整数据 |

未加互锁的默认原始数据保存在`history/pre_guard_default.mat`，用于互锁绕过等价核对；早期重复核心场景与smoke不复制到正式模块。最终结论采用guarded_core与edges重分析结果。验证详情与运行方法分别见[分析](ANALYSIS.md)和[USAGE](../build_process/USAGE.md)。
