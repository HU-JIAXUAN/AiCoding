# dq 电流 PI 与电压限制：波形与验证

- [run_current_loop_validation.m](run_current_loop_validation.m)：原6个工况入口，R2026b回归通过。
- [run_frame_pi_validation.m](run_frame_pi_validation.m)：新增坐标跟踪PI的10项独立MIL。
- [FRAME_TRACKING.md](FRAME_TRACKING.md)：新验证的工况、解析指标与波形解释；`frame_pi_results.mat`（运行验证后生成）及[frame_pi_metrics.json](frame_pi_metrics.json)保存实际参数、输入和30列数据。
- [ANALYSIS.md](ANALYSIS.md)：波形解释和范围。
- `results.mat`（运行验证后生成）：records包含参数、输入、trace、通道名和指标。
- [metrics.json](metrics.json)：实际通过结果与指标。
- [summary.png](summary.png) / [summary.svg](summary.svg)：代表工况。
- [codegen_probe.json](codegen_probe.json)：未成功的配置探路。

[模块入口](../README.md)
