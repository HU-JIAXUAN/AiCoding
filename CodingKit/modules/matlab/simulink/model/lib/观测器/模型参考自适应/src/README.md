# 模型与算法源码

已创建[MrasObserver.slx](MrasObserver.slx)及[MrasObserverTest.slx](MrasObserverTest.slx)。库输出CurrentModelMRAS，21状态显式保持；测试台九列输入、26列日志及8组Scope。

| 文件 | 内容 |
|---|---|
| [mras_step.m](mras_step.m) | 显式下一拍更新、实测历史电流、PI和资格 |
| [mras_output.m](mras_output.m) | 从保持状态输出角度/速度及16路结果，避免电压反馈代数环 |

源码变更需要同步重建SLX中的MATLAB Function；参数M的改动只需重新初始化。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [MrasObserverProtected.slxp](MrasObserverProtected.slxp) | `MrasObserver/CurrentModelMRAS` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
