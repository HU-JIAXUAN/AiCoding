# 验证数据与波形

| 文件 | 内容 |
|---|---|
| [run_mtpa_fw_validation.m](run_mtpa_fw_validation.m) | 7项MTPA、11项弱磁、7项整机断言 |
| [export_mtpa_fw_plots.m](export_mtpa_fw_plots.m) | 从已保存记录绘图，不重新仿真 |
| `results.mat`（运行验证后生成） | records、summary；每个工况含实际参数、输入、trace、channels、metrics |
| [metrics.json](metrics.json) | 通过状态、分组数量和数值指标 |
| [ANALYSIS.md](ANALYSIS.md) | 工况说明、定量结果与边界 |

图以PNG预览、SVG导出保存，分析页按实际文件链接。新增图只由已保存数据绘制。[运行方法](../build_process/USAGE.md) · [参数/通道](../parameter/README.md) · [模块入口](../README.md)
