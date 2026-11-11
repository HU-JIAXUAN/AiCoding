# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》5.9，印刷144–145 / PDF173–174：双观测器位置融合、重叠速度区与注入撤除；已实现HybridFusion独立台，整机组合继续实施 | [原文件、章节及采用说明](../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| MathWorks I-F启动与闭环过渡示例 | https://www.mathworks.com/help/mcb/gs/sensorless-foc-of-pmsm-using-if-ctrl-startup.html |
| MathWorks开环与闭环控制背景 | https://www.mathworks.com/help/mcb/gs/open-loop-and-closed-loop-control.html |
| 本工程接口和建设顺序 | [SENSORLESS_PLAN.md](../../../../docs/plans/SENSORLESS_PLAN.md) |

状态机、平滑包角混合、相位预测与锁存退出为本工程实现，未复制官方内部算法或第三方SLX。SMO方向和首次HFI磁极极性仍由各观测器/上层提供。新融合块仅在合格完整基波角支撑下重新选择低速候选的π分支，不能独立识别初始磁极极性。
