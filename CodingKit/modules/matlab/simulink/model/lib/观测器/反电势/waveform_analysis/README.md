# 波形与分析

[run_emf_validation.m](run_emf_validation.m)分别运行LinearEmfTest和EemfObserverTest。[metrics.json](metrics.json)保存实际完成的数量和指标，`results.mat`（运行验证后生成）保存参数、PLL配置、输入、独立真实轨迹、22列数据和耗时。

正式路径32项已全部通过，分析口径、逐项指标和图入口见[ANALYSIS.md](ANALYSIS.md)。正转、电流变化和反转波形以PNG及SVG保存；它们是解析轨迹下的独立观测器验证，不是物理电机闭环。

[模块入口](../README.md)
