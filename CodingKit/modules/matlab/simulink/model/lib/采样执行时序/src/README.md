# 控制采样与执行时序：模型

- [ControlTiming.slx](ControlTiming.slx)：可复用库，双击子系统查看基础块。
- [TimingTest.slx](TimingTest.slx)：可直接运行的测试或装配模型。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [ControlTiming_ActuationProtected.slxp](ControlTiming_ActuationProtected.slxp) | `ControlTiming/Actuation` |
| [ControlTiming_FeedbackProtected.slxp](ControlTiming_FeedbackProtected.slxp) | `ControlTiming/Feedback` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
