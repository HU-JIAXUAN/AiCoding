# Math 波形与分析

新增同坐标混合的[两场景验证](FRAME_BLEND.md)通过，包含513个代数向量；[脚本](run_frame_blend_validation.m)、`frame_blend_results.mat`（运行验证后生成）、[指标](frame_blend_metrics.json)和[PNG](frame_blend.png)/[SVG](frame_blend.svg)随模块保存。

原13 项 MIL 工况通过，详细条件与误差解释见 [ANALYSIS.md](ANALYSIS.md)。

| 文件 | 内容 |
|---|---|
| [run_clarke_park_validation.m](run_clarke_park_validation.m) | 驱动保存的模型、解析/锚点断言、保存数据和作图 |
| `results.mat`（运行验证后生成） | cases：每项 cfg、七列输入、20 列 trace 和指标；summary：总结果 |
| [metrics.json](metrics.json) | 通过状态、误差、采样、坐标约定、环境与执行时间 |
| [balanced_transform.png](balanced_transform.png) / [SVG](balanced_transform.svg) | 平衡三相→αβ0→dq |
| [round_trip.png](round_trip.png) / [SVG](round_trip.svg) | 完整往返重建及误差 |
| [zero_sequence.png](zero_sequence.png) / [SVG](zero_sequence.svg) | 保留/丢弃零序对比 |
| [independent_inverse.png](independent_inverse.png) / [SVG](independent_inverse.svg) | 独立 dq0 命令的反变换 |
| [angle_offset.png](angle_offset.png) / [SVG](angle_offset.svg) | 角度超前 30° 的 d/q 结果 |

再次运行会覆盖本目录的 MAT、JSON 和十张图文件。运行方式与数据列说明分别见 [USAGE.md](../build_process/USAGE.md)和 [parameter/README.md](../parameter/README.md)。

[返回模块](../README.md)
