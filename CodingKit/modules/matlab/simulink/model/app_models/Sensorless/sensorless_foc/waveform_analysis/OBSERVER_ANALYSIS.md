# EEMF / 磁链闭环波形分析

| 字段 | 记录（文件路径相对于模块目录） |
|---|---|
| 模型文件 | `src/EemfSensorlessFOC.slx`、`src/FluxSensorlessFOC.slx` |
| 参数文件 | `parameter/observer_foc_parameters.m`、`parameter/sensorless_foc_parameters.m`、`parameter/sensorless_foc_validation_parameters.m` |
| 采样周期 | 控制与四组日志50μs；电机对象5μs |
| 求解器/步长 | ode4，固定步长5e-6s |
| 工况 | 正反转、初始角偏置、两倍惯量、电阻偏差、低母线、观测器失效、预期启动失败 |
| 数据文件 | `waveform_analysis/eemf_results.mat`、`waveform_analysis/flux_results.mat`及对应`eemf_metrics.json`、`flux_metrics.json` |

两组各8项MIL，共16项：每组6项正常闭环、1项观测器失效退出、1项预期启动失败基线。默认2s/50μs共40001点；电机对象ode4/5μs。阈值来自原`sensorless_foc_validation_parameters.m`，没有因算法不同而更改外部验收限。

| 观测器 / 工况 | AUTO(s) | 电角度RMS(rad) | 机械速度RMS(rad/s) | 有效率 | 运行电流峰值(A) | 融合电压步进峰值(V) |
|---|---|---|---|---|---|---|
| eemf / positive | 0.4901 | 0.008463466 | 8.982997e-07 | 1 | 3.012132 | 0.09365532 |
| eemf / negative | 0.4901 | 0.008463466 | 8.982652e-07 | 1 | 3.022691 | 0.09956919 |
| eemf / initial_opposite | 0.4901 | 0.008463466 | 8.986085e-07 | 1 | 3.1001 | 0.143777 |
| eemf / high_inertia | 0.4901 | 0.008463859 | 0.001300867 | 1 | 3.017346 | 0.09357781 |
| eemf / resistance_mismatch | 0.4901 | 0.008508333 | 8.805568e-07 | 1 | 3.01601 | 0.100645 |
| eemf / lower_bus | 0.4901 | 0.008463466 | 8.982999e-07 | 1 | 3.012132 | 0.09365532 |
| eemf / observer_loss | 0.4901 | 0.008463459 | 1.975753e-05 | 1 | 3.012132 | 0.09365532 |
| eemf / current_alignment_baseline | — | — | — | — | 3.342825 | — |
| flux / positive | 0.4901 | 0.008217144 | 1.21468e-06 | 1 | 3.012132 | 0.1015085 |
| flux / negative | 0.4901 | 0.008217144 | 1.21467e-06 | 1 | 3.022691 | 0.1085658 |
| flux / initial_opposite | 0.4901 | 0.008217145 | 1.214524e-06 | 1 | 3.1001 | 0.1477126 |
| flux / high_inertia | 0.4901 | 0.008217033 | 0.001226622 | 1 | 3.017346 | 0.1010301 |
| flux / resistance_mismatch | 0.4901 | 0.008260883 | 1.196953e-06 | 1 | 3.01601 | 0.1095867 |
| flux / lower_bus | 0.4901 | 0.008217144 | 1.21468e-06 | 1 | 3.012132 | 0.1015085 |
| flux / observer_loss | 0.4901 | 0.008217198 | 1.738639e-05 | 1 | 3.012132 | 0.1015085 |
| flux / current_alignment_baseline | — | — | — | — | 3.342825 | — |

正常工况计算最后0.2s；失效场景计算1.8s事件之前0.2s。正常稳态要求电角误差RMS<0.12rad、机械速度跟踪RMS<0.5rad/s、有效率>95%；运行时电流<8.8A、参考≤8A、占空比在[0,1]，连续混合期间的物理αβ电压步进<2V。每拍还核对参考的物理坐标混合恒等式、额外坐标修正、实际电压和采样电流来源。

`observer_loss`应在禁用估算器后的连续失锁计数到期时锁存故障、将run和控制请求归零；`current_alignment_baseline`保持原启动失败预期，不计作正常可运行工况。当前0V平均模型不是高阻关断：失效后的dq电流峰值EEMF为15.8882178362A、Flux为15.8882250296A；此前8.8A指标只针对run=1期间。故障后机械能造成短路制动电流，本轮仅证明控制退出，不证明功率级安全关断。后续需建立PWM禁能/高阻与二极管通路，连同带速捕获验证。

EEMF残差来自估计电流减测量电流；Flux残差来自转子磁链幅值误差/L，5A-equivalent在本电机对应5mWb。两者数值不能作为同一物理误差直接排序。默认误差接近也不能推断两种算法在噪声、低速和参数不确定性下等效。

| 数据 | 波形 |
|---|---|
| [eemf_metrics.json](eemf_metrics.json)、`eemf_results.mat`（运行验证后生成） | [正转](eemf_positive.png) / [反转](eemf_negative.png) / [失效](eemf_observer_loss.png)，同名SVG可缩放 |
| [flux_metrics.json](flux_metrics.json)、`flux_results.mat`（运行验证后生成） | [正转](flux_positive.png) / [反转](flux_negative.png) / [失效](flux_observer_loss.png)，同名SVG可缩放 |
| [重建、正式路径和文件校验](observer_foc_verification.json) | 四组默认日志一致性与来源记录 |

数据仅证明当前双精度SPMSM平均模型MIL。EEMF库的凸极能力已有独立验证；本次App尚未覆盖凸极MTPA/弱磁，亦未完成本App的SIL、C2000构建和实机时序。

[参数/Scope](../parameter/OBSERVER_PARAMETERS.md) · [搭建](../build_process/OBSERVER_STEPS.md) · [运行](../build_process/OBSERVER_USAGE.md)
