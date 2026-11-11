# 死区误差、补偿与桥臂开关校验：模型

- [Deadtime.slx](Deadtime.slx)：可复用库，双击子系统查看基础块。
- [DeadtimeTest.slx](DeadtimeTest.slx)：可直接运行的测试或装配模型。
- [SwitchingLegTest.slx](SwitchingLegTest.slx)：可直接运行的测试或装配模型。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [Deadtime_CompensationProtected.slxp](Deadtime_CompensationProtected.slxp) | `Deadtime/Compensation` |
| [Deadtime_SwitchingLegProtected.slxp](Deadtime_SwitchingLegProtected.slxp) | `Deadtime/SwitchingLeg` |
| [Deadtime_VoltageErrorProtected.slxp](Deadtime_VoltageErrorProtected.slxp) | `Deadtime/VoltageError` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
