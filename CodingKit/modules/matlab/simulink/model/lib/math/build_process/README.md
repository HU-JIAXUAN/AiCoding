# Math 搭建与使用

新增[FRAME_BLEND.md](FRAME_BLEND.md)记录同坐标混合公式、运行、参数和结构；[build_frame_blend.m](build_frame_blend.m)在隔离目录创建/刷新候选库与测试台，[initialize_frame_blend_test.m](initialize_frame_blend_test.m)设置加载默认值。

| 文件 | 内容 |
|---|---|
| [DESIGN.md](DESIGN.md) | 四个变换的计算式、坐标与零序定义 |
| [STEPS.md](STEPS.md) | 实际搭建顺序、块参数、连接及测试结构 |
| [USAGE.md](USAGE.md) | 打开模型、调参、独立反变换和 Scope/数据读取 |
| [initialize_clarke_park_test.m](initialize_clarke_park_test.m) | 设置模型工作区默认值与输入 |
| [library_diagram.png](library_diagram.png) | 四个可复用块的库根图 |
| [clarke_diagram.png](clarke_diagram.png) | Clarke 内部 |
| [park_diagram.png](park_diagram.png) | Park 内部 |
| [inverse_park_diagram.png](inverse_park_diagram.png) | InversePark 内部 |
| [inverse_clarke_diagram.png](inverse_clarke_diagram.png) | InverseClarke 内部 |
| [test_diagram.png](test_diagram.png) | 独立测试模型 |

最终模型在 [src/](../src/README.md)，本次没有另存中间过程模型。

[返回模块](../README.md)
