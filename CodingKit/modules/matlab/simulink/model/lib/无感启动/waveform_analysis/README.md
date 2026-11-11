# 波形与分析

R2026b下10项独立MIL通过。入口为[run_startup_validation.m](run_startup_validation.m)，保存`results.mat`（运行验证后生成）、[metrics.json](metrics.json)及[分析](ANALYSIS.md)，含实际参数、输入、时间和12列trace。

| 波形 | 内容 |
|---|---|
| [timeout.png](timeout.png) / [SVG](timeout.svg) | 软件对齐、I-f爬升、等待与超时 |
| [acquired.png](acquired.png) / [SVG](acquired.svg) | 0.58 s接管后停止启动请求 |
| [fault.png](fault.png) / [SVG](fault.svg) | 非法方向触发并锁存故障 |

[模块入口](../README.md) · [Scope说明](../parameter/README.md)

## OpenLoopDrive

[波形分析](OPEN_LOOP_ANALYSIS.md) · [独立测试脚本](run_open_loop_drive_validation.m) · [13 项指标](open_loop_metrics.json)
