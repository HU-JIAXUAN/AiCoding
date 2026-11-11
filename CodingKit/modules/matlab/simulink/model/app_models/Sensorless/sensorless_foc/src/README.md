# 模型

| 模型 | Observer链接 | 运行 |
|---|---|---|
| [SensorlessFOC.slx](SensorlessFOC.slx) | SlidingModeObserver/SMO | [原运行方法](../build_process/USAGE.md) |
| [EemfSensorlessFOC.slx](EemfSensorlessFOC.slx) | EmfObserver/EEMF | [EEMF/Flux运行方法](../build_process/OBSERVER_USAGE.md) |
| [FluxSensorlessFOC.slx](FluxSensorlessFOC.slx) | FluxObserver/Flux | 同上 |

前三份均为直接运行的App，不带Test后缀。五个顶层子系统均为Plant、Measurement、Observer、Controller、VoltageStage；库实现继续在lib中维护。SMO由[initialize_sensorless_foc.m](../build_process/initialize_sensorless_foc.m)初始化，另两者由[initialize_observer_foc.m](../build_process/initialize_observer_foc.m)初始化。

[参数](../parameter/README.md) · [搭建](../build_process/README.md) · [模块入口](../README.md)

[FlyingFluxFOC.slx](FlyingFluxFOC.slx)是第四份App，直接链接PMSMBridgePlant与FluxObserver，使用独立的带速监督和积分准备流程，结构与前三份不同。配置/算法M和使用见[运行说明](../build_process/FLYING_USAGE.md)。`flying_capture_step.m`、`flying_angle_align.m`和`flying_pi_residual.m`由构建器嵌入模型；修改算法需重建隔离候选并验证。

四种扩展物理FOC：[MrasSensorlessFOC.slx](MrasSensorlessFOC.slx)、[EkfSensorlessFOC.slx](EkfSensorlessFOC.slx)、[UkfSensorlessFOC.slx](UkfSensorlessFOC.slx)、[SigmoidSensorlessFOC.slx](SigmoidSensorlessFOC.slx)。均为可运行App，无Test后缀，观测器通过lib链接共享。[参数](../parameter/EXTENSION_PARAMETERS.md)、[运行](../build_process/EXTENSION_USAGE.md)。
