# 模型文件

| 文件 | 作用 |
|---|---|
| [CurrentReference.slx](CurrentReference.slx) | Library；MTPA、FieldWeakening、CurrentLimits、Allocator、TorquePI 五个可复用子系统 |
| [CurrentReferenceTest.slx](CurrentReferenceTest.slx) | 六列独立输入；25列 trace，五组 Scope |

CurrentReferenceTest可直接Run。完整整机在[App/mtpa_fw](../../../app_models/Sensor/mtpa_fw/README.md)。Library 本身用于引用，不作为仿真入口。文件名和模型名一致。

[操作方法](../build_process/USAGE.md) · [模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [CurrentReference_AllocatorProtected.slxp](CurrentReference_AllocatorProtected.slxp) | `CurrentReference/Allocator` |
| [CurrentReference_TorquePIProtected.slxp](CurrentReference_TorquePIProtected.slxp) | `CurrentReference/TorquePI` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
