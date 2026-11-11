# UKF波形、数值与对照

| 文件 | 内容 |
|---|---|
| [ANALYSIS.md](ANALYSIS.md) | 六项记录字段、29项MIL指标、拒绝/故障和范围 |
| [run_ukf_validation.m](run_ukf_validation.m) | 完整29项或指定子集，逐拍检查完整P |
| `results.mat`（运行验证后生成）、[metrics.json](metrics.json) | 完整N×50数据与29/29结果 |
| [run_ukf_numerical_validation.m](run_ukf_numerical_validation.m) | 21项闭式矩、公开参考限定比较与数值边界 |
| `numerical_results.mat`（运行验证后生成）、[numerical_metrics.json](numerical_metrics.json) | 最终21项结果及本机公开对象行为记录 |
| [REFERENCE_BEHAVIOR.md](REFERENCE_BEHAVIOR.md) | 中央协方差权重差异的可手算复现和比较边界 |
| `instance_results.mat`（运行验证后生成）、[instance_metrics.json](instance_metrics.json) | 两实例各自与单独运行一致，内外层Mask配置绑定核对 |
| [compare_ekf_ukf.m](compare_ekf_ukf.m)、`comparison_results.mat`（运行验证后生成）、[comparison_metrics.json](comparison_metrics.json) | 25个共同工况的相同输入/配置对照，静态计算量与未测目标项 |
| [verification.json](verification.json) | 29项文件哈希、11项共享源依赖、重建/正式回放及静态检查 |
| [plot_ukf_results.m](plot_ukf_results.m) | 不打开可见窗口导出三组本模块波形 |
| [ukf_capture.png](ukf_capture.png) / [SVG](ukf_capture.svg) | 默认收敛、创新、标准差及资格 |
| [ukf_dynamics.png](ukf_dynamics.png) / [SVG](ukf_dynamics.svg) | 爬升、反转、电流动态与失配 |
| [ukf_validity.png](ukf_validity.png) / [SVG](ukf_validity.svg) | 零速/错误方向拒绝、数据故障和周期对照 |
| [ukf_ekf_comparison.png](ukf_ekf_comparison.png) / [SVG](ukf_ekf_comparison.svg) | 相同输入EKF/UKF及UT参数初段对照 |

四组PNG已逐张检查；SVG由相同图导出。21纯M、并行1项与25匹配对照不重复计入29项MIL。原始日志50×1×N，records.trace为N×50。普通运行与调参见[USAGE.md](../build_process/USAGE.md)，实际10组Scope见[参数页](../parameter/README.md)。

[模块入口](../README.md)
