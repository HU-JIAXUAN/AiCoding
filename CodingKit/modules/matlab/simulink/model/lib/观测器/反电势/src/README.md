# 模型与离散更新源码

[EmfObserver.slx](EmfObserver.slx)导出LinearEMF和EEMF两种配置的观测块，分别使用[LinearEmfTest.slx](LinearEmfTest.slx)和[EemfObserverTest.slx](EemfObserverTest.slx)运行实验。[emf_predict.m](emf_predict.m)定义显式下一拍预测，构建时嵌入MATLAB Function。SLX内嵌源码已与本M文件核对一致。

运行和调参见[搭建/运行记录](../build_process/README.md)。参数默认值修改后重新初始化即可；修改算法源码后需要在独立模块副本中用[构建脚本](../build_process/build_emf_observer.m)重建模型，再核对与保存结果。

输入电流对应当前状态时刻，作用电压用于下一状态；当前估算反电势来自UnitDelay状态，不直接依赖本拍电压。没有真实角度/速度输入。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [EmfObserver_EEMFProtected.slxp](EmfObserver_EEMFProtected.slxp) | `EmfObserver/EEMF` |
| [EmfObserver_LinearEMFProtected.slxp](EmfObserver_LinearEMFProtected.slxp) | `EmfObserver/LinearEMF` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
