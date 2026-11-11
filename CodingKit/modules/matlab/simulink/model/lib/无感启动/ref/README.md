# 参考资料

| 资料 | 来源 |
|---|---|
| MathWorks I-F控制器的接口和启动背景 | https://www.mathworks.com/help/mcb/ref/ifcontroller.html |
| MathWorks I-F启动与无位置FOC示例 | https://www.mathworks.com/help/mcb/gs/sensorless-foc-of-pmsm-using-if-ctrl-startup.html |
| 本工程无位置传感器计划 | [SENSORLESS_PLAN.md](../../../../docs/plans/SENSORLESS_PLAN.md) |

本库是项目自建的明确电流矢量/时间序列，不是官方I-F Controller块的复刻，也没有其功率优化或速度阻尼算法。未复制外部SLX。

## OpenLoopDrive 补充来源

[MathWorks I-F Controller](https://www.mathworks.com/help/mcb/ref/ifcontroller.html)用于对照定电流与频率爬坡；[开环控制](https://www.mathworks.com/help/mcb/open-loop-control.html)用于对照开环电压链。项目里的状态、阈值与电机是本地仿真设计。
