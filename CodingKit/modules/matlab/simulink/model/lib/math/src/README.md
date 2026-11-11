# Math 模型

| 路径 | 状态 |
|---|---|
| [ClarkePark.slx](ClarkePark.slx) | 已创建 |
| [ClarkeParkTest.slx](ClarkeParkTest.slx) | 已创建 |

新增[FrameBlendTest.slx](FrameBlendTest.slx)调用同一库中的BlendDQ，[blend_dq.m](blend_dq.m)为与库内一致的函数源文件；参数与3组Scope见[专页](../parameter/FRAME_BLEND.md)。

ClarkePark 是库，根下现有Clarke、Park、InversePark、InverseClarke及BlendDQ。四个块可独立复用；双击查看普通子系统内部，修改源块时先解锁库。测试模型通过四个库链接调用源块。

运行使用 ClarkeParkTest。默认正向变换的 dq 与零序被回送到反变换；也可切换为独立 dq0 命令。参数和通道见 [parameter](../parameter/README.md)，操作见 [USAGE.md](../build_process/USAGE.md)。

[返回模块](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [ClarkePark_BlendDQProtected.slxp](ClarkePark_BlendDQProtected.slxp) | `ClarkePark/BlendDQ` |
| [ClarkePark_ClarkeProtected.slxp](ClarkePark_ClarkeProtected.slxp) | `ClarkePark/Clarke` |
| [ClarkePark_InverseClarkeProtected.slxp](ClarkePark_InverseClarkeProtected.slxp) | `ClarkePark/InverseClarke` |
| [ClarkePark_InverseParkProtected.slxp](ClarkePark_InverseParkProtected.slxp) | `ClarkePark/InversePark` |
| [ClarkePark_ParkProtected.slxp](ClarkePark_ParkProtected.slxp) | `ClarkePark/Park` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
