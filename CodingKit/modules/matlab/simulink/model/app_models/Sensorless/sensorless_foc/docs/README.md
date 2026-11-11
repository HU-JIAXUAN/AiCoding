# 无位置 FOC：SMO、EEMF与磁链文档入口

[公式推导.md](公式推导.md)包含共同启动、电流/转矩积分跟踪、坐标状态转移，以及EEMF和磁链观测器接入的原理、离散公式和资格判据。

| 模型 / 资料 | 用途 |
|---|---|
| [SensorlessFOC.slx](../src/SensorlessFOC.slx) | 原SMO闭环App |
| [EemfSensorlessFOC.slx](../src/EemfSensorlessFOC.slx) | EEMF闭环App |
| [FluxSensorlessFOC.slx](../src/FluxSensorlessFOC.slx) | 磁链闭环App |
| [共同参数/Scope](../parameter/README.md)、[观测器参数/Scope](../parameter/OBSERVER_PARAMETERS.md) | 输入、状态、输出和通道 |
| [共同搭建](../build_process/README.md)、[替换搭建](../build_process/OBSERVER_STEPS.md)、[运行](../build_process/OBSERVER_USAGE.md) | 构建和使用 |
| [共同波形](../waveform_analysis/README.md)、[新增分析](../waveform_analysis/OBSERVER_ANALYSIS.md) | 数据、图和验收 |
| [参考来源](../ref/README.md) | 主要书籍与库推导 |

[模块README](../README.md)

新增[FlyingFluxFOC](../src/FlyingFluxFOC.slx)的关断磁链观察、采样年龄、PI积分准备及参考连续建立推导在第10节；[参数/Scope](../parameter/FLYING_PARAMETERS.md)、[搭建](../build_process/FLYING_BUILD.md)、[运行](../build_process/FLYING_USAGE.md)与[波形](../waveform_analysis/FLYING_ANALYSIS.md)同步维护。

新增四物理App：[MrasSensorlessFOC.slx](../src/MrasSensorlessFOC.slx)、[EkfSensorlessFOC.slx](../src/EkfSensorlessFOC.slx)、[UkfSensorlessFOC.slx](../src/UkfSensorlessFOC.slx)、[SigmoidSensorlessFOC.slx](../src/SigmoidSensorlessFOC.slx)。本目录仍只维护本README和[公式推导](公式推导.md)两份MD；第11节说明MRAS/Kalman/sigmoid物理接管。[参数/Scope](../parameter/EXTENSION_PARAMETERS.md)、[搭建](../build_process/EXTENSION_BUILD.md)、[运行](../build_process/EXTENSION_USAGE.md)、[分析](../waveform_analysis/EXTENSION_ANALYSIS.md)。
