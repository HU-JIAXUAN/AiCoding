# UKF库与验证模型

| 文件 | 作用 |
|---|---|
| [UkfObserver.slx](UkfObserver.slx) | 导出UKF的可复用库，不带Test后缀 |
| [UkfObserverTest.slx](UkfObserverTest.slx) | 独立输入验证，10组Scope、50列日志 |
| [ukf_predict.m](ukf_predict.m) | 9点过程传播、圆周统计、完整P及有界数值检查 |

Measurement通过EkfObserver/KalmanMeasurement库链接共用，未在本模块复制校正源码；完整28保持量由每个UKF实例的PriorMemory持有。当前i用于本拍校正，当前u只用于下一拍预测。两实例已验证参数和状态隔离。

算法M改变后在副本中重新构建内嵌Function，参数M改变后刷新并初始化。[搭建](../build_process/STEPS.md) · [运行](../build_process/USAGE.md) · [模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [UkfObserverProtected.slxp](UkfObserverProtected.slxp) | `UkfObserver/UKF` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
