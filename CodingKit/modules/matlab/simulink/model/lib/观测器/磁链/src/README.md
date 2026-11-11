# 库与离散源码

[FluxObserver.slx](FluxObserver.slx)导出Flux库块；[FluxObserverTest.slx](FluxObserverTest.slx)通过库链接进行独立测试。[flux_predict.m](flux_predict.m)更新四个磁链/直流状态；[flux_compute.m](flux_compute.m)从已保存状态计算频率补偿、转子磁链、转矩与残差。库内另以标准块维护频率低通与共用PLL。

[运行方法](../build_process/USAGE.md) · [模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [FluxObserverProtected.slxp](FluxObserverProtected.slxp) | `FluxObserver/Flux` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
