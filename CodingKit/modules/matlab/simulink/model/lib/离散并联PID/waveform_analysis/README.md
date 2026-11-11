# DiscretePID 波形与分析

12 项 MIL 仿真通过，详细工况与解释见 [ANALYSIS.md](ANALYSIS.md)。

| 文件 | 内容 |
|---|---|
| [run_discrete_pid_validation.m](run_discrete_pid_validation.m) | 运行全部工况、断言、保存数据并生成图片 |
| `results.mat`（运行验证后生成） | cases：每工况 cfg、stim、trace；summary：结果摘要 |
| [metrics.json](metrics.json) | 状态、工况名、误差、恢复时间、环境与执行时间 |
| [linear_integration.png](linear_integration.png) / [SVG](linear_integration.svg) | 解析积分与官方 PI 对照 |
| [enable_reset.png](enable_reset.png) / [SVG](enable_reset.svg) | 同步禁能、复位及恢复 |
| [constant_error_windup.png](constant_error_windup.png) / [SVG](constant_error_windup.svg) | 恒误差下回算开关对比 |
| [saturation_recovery.png](saturation_recovery.png) / [SVG](saturation_recovery.svg) | 一阶对象饱和恢复对比 |
| [derivative_step.png](derivative_step.png) / [SVG](derivative_step.svg) | Kd>0 的滤波微分解析响应与官方 PID 对照 |

再次运行会覆盖 results.mat、metrics.json 和十张图文件，不修改模型拓扑或参数默认文件。分析报告中的数值对应当前保存结果；变更算法/参数后应同步报告。

[返回模块](../README.md)
