# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》12.3，印刷311–314 / PDF340–343：滑模电流误差、抖动、滤波相移和平滑切换函数 | [原文件、章节及采用说明](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| 当前 MathWorks Sliding Mode Observer：SPMSM、αβ 输入和调参背景 | https://www.mathworks.com/help/mcb/ref/slidingmodeobserver.html |
| 估算器调参与独立位置对照 | https://www.mathworks.com/help/mcb/gs/tuning-sensorless-position-estimators.html |
| 本项目采用的边界层 SMO、离散滤波与方向公式 | [STEPS.md](../build_process/STEPS.md) |
| 书12.3.3，印刷313/PDF342页式(12.24)：sigmoid无显式低通方案；本实现用tanh等价形式，保存噪声限制及基础滤波对照 | [SIGMOID_STEPS.md](../build_process/SIGMOID_STEPS.md)、[公式推导](../docs/公式推导.md) |
| 工程建设计划与适用边界 | [SENSORLESS_PLAN.md](../../../../../docs/plans/SENSORLESS_PLAN.md) |

官方当前块包含不同的离散反电势观测更新；本项目没有宣称算法逐点相同。暂无复制的外部 SLX；官方块对照需要另行统一SI/标幺与电/机械速度。
