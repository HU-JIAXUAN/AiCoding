# 基础与sigmoid滑模观测器：文档入口

[公式推导.md](公式推导.md)说明原理、公式、量纲、离散状态与实际实现的对应。

| 文件 | 用途 |
|---|---|
| [SlidingModeObserver.slx](../src/SlidingModeObserver.slx) | 可复用库 |
| [SlidingModeObserverTest.slx](../src/SlidingModeObserverTest.slx) | 验证模型 |
| [SigmoidSlidingModeObserver.slx](../src/SigmoidSlidingModeObserver.slx) | 平滑sigmoid库，无显式EMF低通 |
| [SigmoidSlidingModeObserverTest.slx](../src/SigmoidSlidingModeObserverTest.slx) | 独立24列/6组Scope验证 |
| [Sigmoid参数与通道](../parameter/SIGMOID_PARAMETERS.md) | 本地M入口、状态、端口及实际通道 |
| [Sigmoid运行](../build_process/SIGMOID_USAGE.md) | Run、调参和批量验证 |
| [参数、信号和Scope通道](../parameter/README.md) | 本模块维护入口 |
| [搭建过程与运行入口](../build_process/README.md) | 本模块维护入口 |
| [数据、波形和验证结果](../waveform_analysis/README.md) | 本模块维护入口 |
| [参考来源](../ref/README.md) | 本模块维护入口 |

[模块README](../README.md)
