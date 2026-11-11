# SVPWM 与平均逆变器：模型

- [Inverter.slx](Inverter.slx)：可复用库，双击子系统查看基础块。
- [InverterTest.slx](InverterTest.slx)：可直接运行的测试或装配模型。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [Inverter_AverageProtected.slxp](Inverter_AverageProtected.slxp) | `Inverter/Average` |
| [Inverter_SVPWMProtected.slxp](Inverter_SVPWMProtected.slxp) | `Inverter/SVPWM` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
