# 波形与分析

R2026b Update 1下12项MIL通过。[验证脚本](run_angle_tracking_validation.m)保存`results.mat`（运行验证后生成）、[指标/列名](metrics.json)；详细工况与限制见[ANALYSIS.md](ANALYSIS.md)。

| 波形 | 内容 |
|---|---|
| [tracking.png](tracking.png) / [SVG](tracking.svg) | 解析恒速捕获、速度及包角误差 |
| [dropout.png](dropout.png) / [SVG](dropout.svg) | 幅值丢失时保持、valid失效和重新捕获 |
| [instances.png](instances.png) / [SVG](instances.svg) | 不同参数实例的角度与速度响应 |

新增3项参数隔离测试通过，入口为[run_pll_instance_validation.m](run_pll_instance_validation.m)，保存`instances.mat`（运行验证后生成）、[独立单位指标](instance_metrics.json)和[分析](INSTANCES.md)。新增Mask后已重跑PLL12项、SMO14项，全部通过。

限速和无幅值工况按有界/无效判据通过，不代表超范围或无幅值时仍能准确跟踪。
