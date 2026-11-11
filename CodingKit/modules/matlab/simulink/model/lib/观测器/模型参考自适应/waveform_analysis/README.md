# 波形与分析

24项独立MIL及并行实例检查通过；从M源码重新搭建、正式目录默认26列波形及时间逐点相同。独立规定轨迹不作为电机整机接管结果。

| 文件 | 内容 |
|---|---|
| [ANALYSIS.md](ANALYSIS.md) | 模型/参数/周期/求解器/工况/数据六字段、修正、指标和边界 |
| [run_mras_validation.m](run_mras_validation.m) | 24项独立输入及断言，默认/选择工况分开保存 |
| `results.mat`（运行验证后生成）、[metrics.json](metrics.json) | 实际配置、输入、真实轨迹、26列日志及窗口RMS |
| [transient_metrics.json](transient_metrics.json) | 全过程有效比例、有效期间误差峰值及资格丢失 |
| `tuning_results.mat`（运行验证后生成）、[tuning_metrics.json](tuning_metrics.json) | 20→30 Hz设计频率、同一斜坡和新增持续资格断言 |
| `instance_results.mat`（运行验证后生成）、[instance_metrics.json](instance_metrics.json) | 两个不同Mask配置并行与各自单独输出对照 |
| [verification.json](verification.json) | 正式路径、重建、内嵌源码、文件指纹和窗口核对 |
| [plot_mras_results.m](plot_mras_results.m) | 后台导出并关闭图窗 |
| [捕获](mras_capture.svg)、[敏感性](mras_sensitivity.svg)、[拒绝/复位](mras_refusal.svg) | 同名PNG可预览 |

Scope和26列见[参数页](../parameter/README.md)，运行步骤见[USAGE](../build_process/USAGE.md)。

[模块入口](../README.md)

## 主机代码与类型回归

[HOST_CODE_ANALYSIS.md](HOST_CODE_ANALYSIS.md)记录状态更新函数的double/single MEX与double SIL，三项通过。入口[run_mras_host_validation.m](run_mras_host_validation.m)，参数[mras_host_test_parameters.m](../parameter/mras_host_test_parameters.m)，[typed_verification.json](typed_verification.json)绑定正式源文件及原24项lib/10项App回归。[实际报告](host_codegen/host_verification.json)保留工具链/指标；完整SLX/App的single转换与App SIL未执行。
