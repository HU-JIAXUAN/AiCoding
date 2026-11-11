# 模型文件

| 模型 | 用途 |
|---|---|
| [SlidingModeObserver.slx](SlidingModeObserver.slx) | Library，SMO子系统 |
| [SlidingModeObserverTest.slx](SlidingModeObserverTest.slx) | 可直接Run的独立测试台，五组Scope、22列trace |
| [SigmoidSlidingModeObserver.slx](SigmoidSlidingModeObserver.slx) | SigmoidSMO可复用库，无显式EMF低通 |
| [SigmoidSlidingModeObserverTest.slx](SigmoidSlidingModeObserverTest.slx) | 独立验证，6组Scope、24列trace |
| [sigmoid_smo_measure.m](sigmoid_smo_measure.m) / [sigmoid_smo_predict.m](sigmoid_smo_predict.m) | 内嵌MATLAB Function源码，更新后需重新构建SLX |

SMO库通过库链接引用AngleTracking/PLL，测试台引用同一个SMO。PostLoadFcn加入两个模块路径并装入默认参数与合成输入，无需手工填base workspace。

[模块入口](../README.md) · [运行方法](../build_process/USAGE.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [SigmoidSlidingModeObserverProtected.slxp](SigmoidSlidingModeObserverProtected.slxp) | `SigmoidSlidingModeObserver/SigmoidSMO` |
| [SlidingModeObserverProtected.slxp](SlidingModeObserverProtected.slxp) | `SlidingModeObserver/SMO` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
