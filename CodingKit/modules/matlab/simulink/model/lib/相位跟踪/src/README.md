# 模型文件

| 模型 | 用途 |
|---|---|
| [AngleTracking.slx](AngleTracking.slx) | Library，复用PLL子系统 |
| [AngleTrackingTest.slx](AngleTrackingTest.slx) | 可直接Run的独立测试台，三组Scope、12列trace |
| [AngleTrackingInstancesTest.slx](AngleTrackingInstancesTest.slx) | 两个PLL库链接分别使用pllA/pllB，AngleScope/SpeedScope各两通道，4列trace |

配置位于本模块parameter。PostLoadFcn从build_process初始化模型工作区，重新打开恢复默认输入。正常使用无需重建；App/SMO通过库链接复用PLL。

[模块入口](../README.md) · [操作教程](../build_process/USAGE.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [AngleTrackingProtected.slxp](AngleTrackingProtected.slxp) | `AngleTracking/PLL` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
