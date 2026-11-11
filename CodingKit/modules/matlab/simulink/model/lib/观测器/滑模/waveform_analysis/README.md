# 波形与分析

新增sigmoid的[分析与原噪声失败](SIGMOID_ANALYSIS.md)、[22项MIL](sigmoid_metrics.json)、`sigmoid_results.mat`（运行验证后生成）、[源码/正式路径证明](sigmoid_verification.json)和[运行入口](run_sigmoid_smo_validation.m)均随本模块保存。另有[纯M10项](sigmoid_kernel_metrics.json)、[实例隔离](sigmoid_instance_metrics.json)和[6次匹配对照](sigmoid_comparison_metrics.json)。绘图入口为[plot_sigmoid_smo_results.m](plot_sigmoid_smo_results.m)，3组PNG/SVG链接见分析页。

R2026b Update 1下14项MIL通过。[验证脚本](run_smo_validation.m)保存`results.mat`（运行验证后生成）及[指标/列名](metrics.json)，详见[ANALYSIS.md](ANALYSIS.md)。

| 波形 | 内容 |
|---|---|
| [tracking.png](tracking.png) / [SVG](tracking.svg) | 200电角rad/s下捕获、当前预测和误差 |
| [reversal.png](reversal.png) / [SVG](reversal.svg) | 外部已知方向的过零、无效区和重新捕获 |
| [compensation.png](compensation.png) / [SVG](compensation.svg) | 同一工况开/关LPF相移补偿 |

修改绘图样式可运行[export_smo_plots.m](export_smo_plots.m)，直接读取已保存数据，不重复仿真。
