# PMSM 数学电机与刚性负载：波形与验证

- [run_pmsm_plant_validation.m](run_pmsm_plant_validation.m)：5个工况入口。
- [ANALYSIS.md](ANALYSIS.md)：波形解释和范围。
- `results.mat`（运行验证后生成）：records包含参数、输入、trace、通道名和指标。
- [metrics.json](metrics.json)：实际通过结果与指标。
- [summary.png](summary.png) / [summary.svg](summary.svg)：代表工况。

高频/饱和对象：[run_hf_plant_validation.m](run_hf_plant_validation.m)运行14项MIL；[HF_ANALYSIS.md](HF_ANALYSIS.md)、`hf_results.mat`（运行验证后生成）、[hf_metrics.json](hf_metrics.json)及[hf_verification.json](hf_verification.json)保存结果。图名统一以hf_开头，独立于原有5项线性对象结果。

共用估计过程：[run_sensorless_process_validation.m](run_sensorless_process_validation.m)、[sensorless_process_metrics.json](sensorless_process_metrics.json)与[SENSORLESS_PROCESS.md](SENSORLESS_PROCESS.md)记录4个过程/4个测量偏导点的纯M核对，不重复计入物理MIL。

桥耦合对象：[run_bridge_validation.m](run_bridge_validation.m)执行15项模型检查，[run_bridge_kernel_checks.m](run_bridge_kernel_checks.m)执行18组纯M核对。[BRIDGE_ANALYSIS.md](BRIDGE_ANALYSIS.md)、[bridge_metrics.json](bridge_metrics.json)、`bridge_results.mat`（运行验证后生成）、[bridge_kernel_checks.json](bridge_kernel_checks.json)和[验证记录](bridge_verification.json)说明物理依据和范围，三组PNG/SVG以bridge_开头。

运行时母线：[10项检查](run_bridge_bus_validation.m)、[波形生成](export_bridge_bus_plots.m)、[分析](BRIDGE_BUS_ANALYSIS.md)、[结果](bus_results.json)和[验证记录](bus_verification.json)另行维护，三组PNG/SVG以bus_开头，原始MAT保存实际参数/输入/34列数据；六项正常/数值与四项拒绝分开说明。

[模块入口](../README.md)
