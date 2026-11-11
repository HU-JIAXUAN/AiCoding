# 波形与验证

[run_observer_compare_validation.m](run_observer_compare_validation.m)运行8项完整PMSM MIL，记录正反转、反馈延迟0/1/2拍、观测器Rs偏差20%、观测器禁能/复位与强制转速对照。R2026b下8/8通过，详见[ANALYSIS.md](ANALYSIS.md)、[metrics.json](metrics.json)和`results.mat`（运行验证后生成）。波形：[positive.png](positive.png)/[SVG](positive.svg)、[negative.png](negative.png)/[SVG](negative.svg)、[two_feedback_ticks.png](two_feedback_ticks.png)/[SVG](two_feedback_ticks.svg)。

observer_trace为28列监测数据，sensor_trace为原控制52列数据。参数快照随每例保留；Scope和列顺序见[参数页](../parameter/README.md)。

[模块入口](../README.md)
