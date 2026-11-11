# EKF模型与源码

| 文件 | 作用 |
|---|---|
| [EkfObserver.slx](EkfObserver.slx) | 可复用库，导出完整EKF与共用KalmanMeasurement |
| [EkfObserverTest.slx](EkfObserverTest.slx) | 独立连续dq输入；10组Scope和完整50列日志 |
| [kalman_current_update.m](kalman_current_update.m) | 电流校正、Joseph协方差、角变化率、资格与复位 |
| [ekf_predict.m](ekf_predict.m) | 共用SPMSM过程/Jacobian，计算下一拍先验 |

两个M函数内嵌于SLX的MATLAB Function；修改算法后按[搭建步骤](../build_process/STEPS.md)重新构建副本。模型通过Mask cfg分别配置，各实例保存独立28元素状态；共用校正块没有额外状态。读取SLX或调用测试台回调会添加本模块和过程函数路径，不需要base workspace同名变量。

[运行方法](../build_process/USAGE.md) · [模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [EkfObserver_EKFProtected.slxp](EkfObserver_EKFProtected.slxp) | `EkfObserver/EKF` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
