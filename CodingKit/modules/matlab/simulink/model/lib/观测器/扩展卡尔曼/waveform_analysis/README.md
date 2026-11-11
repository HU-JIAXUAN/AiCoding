# EKF波形与分析

| 文件 | 内容 |
|---|---|
| [ANALYSIS.md](ANALYSIS.md) | 六项记录字段、指标、拒绝/故障、完整协方差及范围 |
| [run_ekf_validation.m](run_ekf_validation.m) | 25项独立输入MIL；子集另存subset文件 |
| `results.mat`（运行验证后生成）、[metrics.json](metrics.json) | 本次25/25结果和N×50逐拍数据 |
| [run_kalman_qualification_check.m](run_kalman_qualification_check.m) | 相反速度分支的2项合成资格检查 |
| `qualification_results.mat`（运行验证后生成）、[qualification_metrics.json](qualification_metrics.json) | 合成状态与默认/放宽门限结果 |
| `instance_results.mat`（运行验证后生成）、[instance_metrics.json](instance_metrics.json) | 两个完整EKF并行与各自单独运行一致，嵌套参数绑定已核对 |
| [verification.json](verification.json) | 源重建、正式路径回放、Scope、静态检查及32项文件哈希 |
| [plot_ekf_results.m](plot_ekf_results.m)、[plot_kalman_observer_results.m](plot_kalman_observer_results.m) | 本模块绘图及后续同类滤波器共用绘图 |
| [ekf_capture.png](ekf_capture.png) / [SVG](ekf_capture.svg) | 收敛、创新和资格 |
| [ekf_dynamics.png](ekf_dynamics.png) / [SVG](ekf_dynamics.svg) | 动态、反转和失配 |
| [ekf_validity.png](ekf_validity.png) / [SVG](ekf_validity.svg) | 拒绝、异常和离散周期比较 |

独立轨迹、合成资格、并行实例及纯M过程偏导检查分别计数。当前不是物理FOC接管、SIL或实机结果。原始日志50×1×N，保存的records.trace为N×50。

[运行与Scope](../build_process/USAGE.md) · [模块入口](../README.md)
