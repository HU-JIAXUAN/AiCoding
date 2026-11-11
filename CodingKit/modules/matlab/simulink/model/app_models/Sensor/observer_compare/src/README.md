# 模型

[SensorObserverCompare.slx](SensorObserverCompare.slx)是完整Sensor App，新增ObserverMonitor分支与原控制分开；SMO来自[共用库](../../../../lib/观测器/滑模/src/SlidingModeObserver.slx)，其内部PLL继续引用AngleTracking。默认50µs控制/估算、5µs Plant步长。

双击ObserverMonitor进入电压重建、年龄对齐、库观测器、误差记录与6组Scope。根层原控制和11组Scope沿用Sensor基线；新观测器无输出反馈到控制。加载回调设置本模块模型工作区配置。

[模块入口](../README.md) · [运行方法](../build_process/USAGE.md)
