# 波形与分析

[run_flux_validation.m](run_flux_validation.m)完成24项独立MIL，[metrics.json](metrics.json)保存窗口指标，`results.mat`（运行验证后生成）保存实际参数、输入、真值评估及24列trace。[ANALYSIS.md](ANALYSIS.md)列出工况和结论，并链接正常、偏置、纯积分、无频率补偿及反转波形。所有图另有同名SVG。

反例的检查通过表示观察到预期缺陷或拒绝资格，不表示该配置适合闭环。当前只有独立积木MIL及正式路径默认复查，尚无App替换、SIL或目标结果。

[模块入口](../README.md)
