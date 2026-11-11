# 搭建与使用记录

| 文件 | 内容 |
|---|---|
| [DESIGN.md](DESIGN.md) | 公式、约束、状态与适用范围 |
| [STEPS.md](STEPS.md) | 先 MTPA 再弱磁的逐块搭建过程 |
| [USAGE.md](USAGE.md) | GUI运行、修改参数、脚本实验和读取波形 |
| [initialize_mtpa_fw_model.m](initialize_mtpa_fw_model.m) | 打开模型时加入本地依赖并设置 Model Workspace 默认值 |
| [run_mtpa_fw_case.m](run_mtpa_fw_case.m) | SimulationInput 单次覆盖；返回实际参数、输入和 trace |
| [model_channels.json](model_channels.json) | 从实际模型连接整理的数据列、Scope分组及源块索引 |

模型存放在 [src](../src/README.md)。验证脚本与原始结果存放在 [waveform_analysis](../waveform_analysis/README.md)。[模块入口](../README.md)
