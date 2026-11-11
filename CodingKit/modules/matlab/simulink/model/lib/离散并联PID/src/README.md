# DiscretePID 模型文件

| 路径 | 状态 |
|---|---|
| [DiscretePID.slx](DiscretePID.slx) | 已创建 |
| [DiscretePIDTest.slx](DiscretePIDTest.slx) | 已创建 |

DiscretePID 是库，Controller 为复用块；运行验证使用 DiscretePIDTest。库块包含九个掩码参数、三输入和五输出，接口与运行命令见[模块 README](../README.md)。

[搭建过程](../build_process/README.md) · [返回模块](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [DiscretePIDProtected.slxp](DiscretePIDProtected.slxp) | `DiscretePID/Controller` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
