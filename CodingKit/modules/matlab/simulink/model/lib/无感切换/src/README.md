# 模型与算法

- [SensorlessHandover.slx](SensorlessHandover.slx)：Handover库，11个输入、11个输出；九状态Unit Delay和无persistent的SequenceStep。
- [SensorlessHandoverTest.slx](SensorlessHandoverTest.slx)：可直接Run的独立测试台，六组Scope、22列trace。
- [handover_step.m](handover_step.m)：MATLAB Function源，由搭建脚本导入SLX；源和函数块修改须同步并验证。

- SensorlessHandover.slx新增HybridFusion导出，原Handover保留。
- [HybridFusionTest.slx](HybridFusionTest.slx)：独立两路解析估计测试台，六组Scope和27列trace。
- [hybrid_fusion_step.m](hybrid_fusion_step.m)：20状态下一拍更新与融合。
- [hybrid_injection_output.m](hybrid_injection_output.m)：只读取保持状态与命令的注入输出，避免代数环。

[模块入口](../README.md) · [使用方法](../build_process/USAGE.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [SensorlessHandover_HandoverProtected.slxp](SensorlessHandover_HandoverProtected.slxp) | `SensorlessHandover/Handover` |
| [SensorlessHandover_HybridFusionProtected.slxp](SensorlessHandover_HybridFusionProtected.slxp) | `SensorlessHandover/HybridFusion` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
