# App波形与分析

此前第15步的7项整机数据与18项组件数据共同保存在`results.mat`（运行验证后生成），参数/输入/74列trace均在records.motor下。它作为原始验证归档保留，未因本次迁移复制大数据文件。

[分析与波形](../../../../lib/MTPA弱磁/waveform_analysis/ANALYSIS.md) · [指标](../../../../lib/MTPA弱磁/waveform_analysis/metrics.json) · [运行脚本](../../../../lib/MTPA弱磁/waveform_analysis/run_mtpa_fw_validation.m)

模型文件：src/MTPAFWMotor.slx。参数文件：model/lib/MTPA弱磁/parameter/reference_case_parameters.m（跨模块引用）。采样周期100µs，弱磁/外环1ms，ode4/5µs。工况和数据文件以上述归档及本次迁移记录为准。

[返回模块](../README.md)
