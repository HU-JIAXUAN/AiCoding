# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》2.3.2，印刷31–33 / PDF60–62；12.3.2，印刷311 / PDF340：扩展反电势幅值、αβ电压方程和Ld/Lq差异 | [原文件、章节及采用说明](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| IPMSM扩展反电势及状态方程 | https://www.mathworks.com/help/mcb/ref/extendedemfobserver.html |
| 无位置传感器建设计划 | [SENSORLESS_PLAN.md](../../../../../docs/plans/SENSORLESS_PLAN.md) |
| 共用PLL | [相位跟踪](../../../相位跟踪/README.md) |

本模块使用自建四状态全阶Luenberger观测器，不声称与官方块的降阶实现逐点相同。

[模块入口](../README.md)
