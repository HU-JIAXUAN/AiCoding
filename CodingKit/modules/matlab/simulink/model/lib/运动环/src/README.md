# 速度PI、位置P与离散速度给定：模型

- [MotionControl.slx](MotionControl.slx)：可复用库，双击子系统查看基础块。
- [MotionLoopTest.slx](MotionLoopTest.slx)：原Position/Speed测试台。
- [SpeedProfileTest.slx](SpeedProfileTest.slx)：可直接运行的离散给定测试台，复用MotionControl/SpeedProfile。

库共导出Position、Speed、SpeedProfile。新增块不替换旧Position中的RateLimiter；App按需要单独调用带复位的SpeedProfile。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [MotionControl_PositionProtected.slxp](MotionControl_PositionProtected.slxp) | `MotionControl/Position` |
| [MotionControl_SpeedProtected.slxp](MotionControl_SpeedProtected.slxp) | `MotionControl/Speed` |
| [MotionControl_SpeedProfileProtected.slxp](MotionControl_SpeedProfileProtected.slxp) | `MotionControl/SpeedProfile` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
