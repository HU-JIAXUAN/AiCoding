# PMSM对象：常参数、非线性高频与估计过程：文档入口

[公式推导.md](公式推导.md)说明原理、公式、量纲、离散状态与实际实现的对应。

| 文件 | 用途 |
|---|---|
| [PMSMHighFrequencyPlant.slx](../src/PMSMHighFrequencyPlant.slx) | 可复用库 |
| [PMSMHighFrequencyPlantTest.slx](../src/PMSMHighFrequencyPlantTest.slx) | 验证模型 |
| [PMSMPlant.slx](../src/PMSMPlant.slx) | 可复用库 |
| [PMSMPlantTest.slx](../src/PMSMPlantTest.slx) | 验证模型 |
| [PMSMBridgePlant.slx](../src/PMSMBridgePlant.slx) | 桥/线性电机耦合库 |
| [PMSMBridgePlantTest.slx](../src/PMSMBridgePlantTest.slx) | 关断/整流/短路验证模型 |
| [参数、信号和Scope通道](../parameter/README.md) | 本模块维护入口 |
| [搭建过程与运行入口](../build_process/README.md) | 本模块维护入口 |
| [数据、波形和验证结果](../waveform_analysis/README.md) | 本模块维护入口 |
| [参考来源](../ref/README.md) | 本模块维护入口 |

新增[PMSMBridgeBusPlant.slx](../src/PMSMBridgeBusPlant.slx)与[PMSMBridgeBusPlantTest.slx](../src/PMSMBridgeBusPlantTest.slx)，运行时母线的原理和公式见[公式推导第9节](公式推导.md#9-运行时母线输入)，参数、过程量和九组Scope见[说明](../parameter/BRIDGE_BUS_PARAMETERS.md)。

[模块README](../README.md)
