# 波形与验证

独立位置启动22项、HFI闭环24项物理MIL通过，新增混合控制18项，合计64项App MIL；lib轴线30项、探针27项和SpeedProfile8项另计，不重复计数。

| 文件 | 内容 |
|---|---|
| [HYBRID_ANALYSIS.md](HYBRID_ANALYSIS.md) | 物理交接、注入、π分支及速度环修正分析 |
| [run_hfi_hybrid_validation.m](run_hfi_hybrid_validation.m) | 18项物理混合闭环MIL；可选工况和普通/加速模式 |
| `hybrid_results.mat`（运行验证后生成）、[hybrid_metrics.json](hybrid_metrics.json) | 每项参数/输入/12份日志及指标 |
| [hybrid_transition_metrics.json](hybrid_transition_metrics.json)、[hybrid_verification.json](hybrid_verification.json) | 控制真实接线、交接窗口统计、复现及文件指纹 |
| `hybrid_speed_tuning.mat`（运行验证后生成）、[hybrid_speed_tuning.json](hybrid_speed_tuning.json) | 原20 rad/s速度环失败与30 rad/s修正对照，门限及窗口相同 |
| [plot_hfi_hybrid_results.m](plot_hfi_hybrid_results.m) | 导出往返、纹波、分支、故障及反转图 |
| [双向往返](hybrid_round_trip.svg)、[原始纹波](hybrid_ripple.svg)、[分支恢复](hybrid_branch_return.svg) | 完整物理响应及50 μs局部波形 |
| [故障](hybrid_faults.svg)、[反转](hybrid_reversal.svg) | 来源失效退出及跨零双向观测交接 |
| [ANALYSIS.md](ANALYSIS.md) | 工况、峰值、实际剂量、复位及适用边界 |
| [run_hfi_startup_validation.m](run_hfi_startup_validation.m) | 22项实际组合MIL，后台运行并关闭模型 |
| `startup_results.mat`（运行验证后生成） | 每项配置、时间及6份完整波形 |
| [startup_metrics.json](startup_metrics.json) | 22项指标与通过状态 |
| [startup_verification.json](startup_verification.json) | 受测位置、正式路径默认运行、嵌入源码及输出核对 |
| [plot_hfi_startup_results.m](plot_hfi_startup_results.m) | 从保存数据导出图，不打开图窗 |
| [启动顺序](startup_sequence.svg) | 轴线、阶段、峰值和实际伏秒 |
| [π极性及ADC](startup_polarity.svg) | 默认、反向极性、量化噪声的完整角误差及valid |
| [拒绝工况](startup_rejection.svg) | 无饱和对比不足、不等伏秒拒绝识别 |
| [FOC_ANALYSIS.md](FOC_ANALYSIS.md) | 闭环24项覆盖、动态延迟/噪声、修正和适用边界 |
| [run_hfi_foc_validation.m](run_hfi_foc_validation.m) | 24项物理闭环MIL，含预期退出/偏差反例 |
| `foc_results.mat`（运行验证后生成） | 每项配置、时间和九份50 μs完整日志 |
| [foc_metrics.json](foc_metrics.json) | 闭环逐项数值与状态 |
| [foc_verification.json](foc_verification.json) | 输出哈希、正式路径、脚本复现及旧运动环核对 |
| `foc_repair_comparison.mat`（运行验证后生成） | 两项开发失败及修正后原始数据，区别于当前全量结果 |
| [plot_hfi_foc_results.m](plot_hfi_foc_results.m) | 导出图，保留HFI窗口完整采样 |
| [闭环跟踪](foc_tracking.svg)、[HFI纹波](foc_hfi_ripple.svg) | 速度/负载、有效角误差及3 ms电流/电压 |
| [反转](foc_reversal.svg)、[修正前后](foc_repairs.svg) | 反向过零及实际失败修正对照 |

同名PNG可预览，SVG供导出；位置启动Scope见[参数说明](../parameter/README.md)，FOC九组Scope及九份日志严格见[FOC参数页](../parameter/FOC_PARAMETERS.md)；混合模型15组Scope和12份日志见[混合参数页](../parameter/HYBRID_PARAMETERS.md)。

[模块入口](../README.md)
