# 搭建与运行

| 文件 | 内容 |
|---|---|
| [STEPS.md](STEPS.md) | 物理激励、解调方程、双角PLL、复位和采样年龄 |
| [USAGE.md](USAGE.md) | 打开模型、运行、改参数、读取38列trace及10组Scope |
| [build_hfi_observer.m](build_hfi_observer.m) | 用model_edit复现库和测试台；拒绝覆盖已有SLX |
| [initialize_hfi_test.m](initialize_hfi_test.m) | 模型工作区初始化与依赖路径 |
| [hfi_stimulus.m](hfi_stimulus.m) | 7列精确采样激励，局部随机种子 |
| [PROBE_BUILD.md](PROBE_BUILD.md) | 正交探针回归、状态和时间语义 |
| [PROBE_USAGE.md](PROBE_USAGE.md) | 探针运行、改参数和读取38列数据 |
| [build_hfi_probe.m](build_hfi_probe.m) | 向同一库追加SaliencyProbe及测试台 |
| [initialize_hfi_probe_test.m](initialize_hfi_probe_test.m) | 探针模型工作区初始化 |
| [build_hfi_calibration.m](build_hfi_calibration.m) | 扩展既有HFIAxis和测试台，加入实测逆电感均值接口 |
| [build_hfi_polarity.m](build_hfi_polarity.m) | 在同一库追加PolarityPulse，独立生成请求和完整角度资格 |
| [POLARITY_BUILD.md](POLARITY_BUILD.md) | 极性状态、实际伏秒和因果连接，链接组合测试台 |
| [probe_test_diagram.png](probe_test_diagram.png) | 实际测试台连接图 |

[模块入口](../README.md)
