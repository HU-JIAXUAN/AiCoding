# 波形与分析

R2026b下19项独立MIL通过。[run_handover_validation.m](run_handover_validation.m)保存`results.mat`（运行验证后生成）和[metrics.json](metrics.json)，详细条件与范围见[ANALYSIS.md](ANALYSIS.md)。

| 波形 | 内容 |
|---|---|
| [capture.png](capture.png) / [SVG](capture.svg) | 普通捕获、平滑角度过渡、基准/规划速度和AUTO |
| [phase_jump.png](phase_jump.png) / [SVG](phase_jump.svg) | valid仍为1但相位突跳1.5 rad，预测延续后锁存退出 |
| [blend_pause.png](blend_pause.png) / [SVG](blend_pause.svg) | 混合中短时失效，beta暂停后继续 |

新增HybridFusion完成30项独立MIL，原19项逐条回放一致；两类分开保存。

| 文件 | 内容 |
|---|---|
| [run_hybrid_fusion_validation.m](run_hybrid_fusion_validation.m) | 30项融合/资格/分支/注入/故障验证 |
| [FUSION_ANALYSIS.md](FUSION_ANALYSIS.md) | 工况、验收性质及整机边界 |
| `fusion_results.mat`（运行验证后生成） / [fusion_metrics.json](fusion_metrics.json) | 参数、输入、27列完整日志和逐项结果 |
| [fusion_verification.json](fusion_verification.json) | 受测哈希、重新搭建、正式路径及旧19项逐点回放 |
| [plot_hybrid_fusion_results.m](plot_hybrid_fusion_results.m) | 后台导出，不显示图窗 |
| [fusion_round_trip.svg](fusion_round_trip.svg) / [PNG](fusion_round_trip.png) | 升降速、π返回、误差、权重与注入 |
| [fusion_faults.svg](fusion_faults.svg) / [PNG](fusion_faults.png) | 短时恢复、持续失效和无分支支撑退出 |

测试使用解析观测输入，未将结果计为电机实际电流、转矩、SIL或板测证据。
