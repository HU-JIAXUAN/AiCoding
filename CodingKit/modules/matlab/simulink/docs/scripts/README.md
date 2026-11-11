# 运行入口

本次环境安装及无位置传感器建模的临时目录和项目编译缓存清理由[clear_sensorless_build_cache.ps1](clear_sensorless_build_cache.ps1)处理。全部验证完成并退出安装器后，使用PowerShell 7执行：

```powershell
pwsh -NoProfile -File ".\docs\scripts\clear_sensorless_build_cache.ps1" -WhatIf
pwsh -NoProfile -File ".\docs\scripts\clear_sensorless_build_cache.ps1"
```

脚本只清理固定登记的本次临时目录、已知自动备份和4份本次生成的Simulink编译缓存，不扫描删除用户的整个Temp目录；不删除SLX源模型、参数、波形结果、已安装产品、用户目录中已部署的MinGW编译器或下载目录里的MATLAB原安装包。本轮模型、源码生成及主机检查证据已归档到各模块；实际执行状态见[清理记录](../validation/cleanup.json)。

清理前还会比较本次工作目录中用户编辑的`symbol_table/符号定义表.md`与正式符号表的SHA256；不一致时停止，保留未归档的用户修订。若临时目录中的`SensorlessFieldWeakeningFOC.slx`尚无正式`model/app_models/Sensorless/sensorless_fw/src/`输出，也停止整批清理。临时`extension_foc_build/src`下出现MRAS/EKF/UKF/sigmoid完整App时，也必须已有正式模型及通过的`extension_verification.json`，才允许清理。`-WhatIf`同样执行这些保留检查。

脚本登记10个本次生成的`.slx.r2026a`备份：参数绑定时的9个，以及保存关闭MotorExperiment时新增的1个。仅当路径和SHA256均匹配原始文件时清除；10个均已通过`-BackupsOnly`清理，源SLX、结果及当前工作保存。清理后临时回滚副本随本次工作目录移除，正式源模型与归档验证结果保留。`-WhatIf`可预览，已不存在的条目自动跳过。[清理记录](../validation/cleanup.json)分别记录备份、临时目录和编译缓存的实际清理结果。

公共测试运行器保存在本目录，专用组件验证仍随模块保存。[motor_case_parameters.m](motor_case_parameters.m)只组合各模块自己parameter中的M文件；默认测试输入和时长不再在通用初始化函数里重复定义。全部入口与重新加载示例见[参数使用索引](../guide/PARAMETER_USAGE.md)。[initialize_motor_paths.m](initialize_motor_paths.m)加入当前20个lib和6个App功能目录的src、parameter、build_process；包含HFI/MRAS/EKF/UKF及sensorless_hfi/sensorless_fw。waveform_analysis专用验证入口按模块运行说明另加，不将ref和缓存加入搜索路径。

新增[Sensor并行观测对照](../../model/app_models/Sensor/observer_compare/build_process/USAGE.md)运行说明及[8项验证入口](../../model/app_models/Sensor/observer_compare/waveform_analysis/run_observer_compare_validation.m)；新[坐标跟踪PI 10项入口](../../model/lib/电流环/waveform_analysis/run_frame_pi_validation.m)随电流环模块维护。

组件入口：

| 入口 | 用途 |
|---|---|
| [DiscretePID 验证脚本](../../model/lib/离散并联PID/waveform_analysis/run_discrete_pid_validation.m) | 运行 12 个工况、检查断言、保存数据与波形 |
| [DiscretePID 初始化](../../model/lib/离散并联PID/build_process/initialize_discrete_pid_test.m) | 设置测试模型工作区默认值与输入 |
| [操作教程](../../model/lib/离散并联PID/build_process/USAGE.md) | 界面运行、调参、构造输入与观察 Scope |
| [Math 验证脚本](../../model/lib/math/waveform_analysis/run_clarke_park_validation.m) | 运行 13 个变换工况，保存解析对照、零序与往返数据 |
| [Math 操作教程](../../model/lib/math/build_process/USAGE.md) | 正反变换运行、修改角度/输入、查看四组 Scope |

06–14的可执行入口：

| 入口 | 用途 |
|---|---|
| [run_motor_case.m](run_motor_case.m) | SimulationInput单轮覆盖，返回实际参数、输入、trace |
| [initialize_motor_model.m](initialize_motor_model.m) | 各测试模型加载默认值与本地路径 |
| [run_motor_validation.m](run_motor_validation.m) | 全部45项或指定功能组验证与保存 |
| [整机教程](../../model/app_models/Sensor/experiment/build_process/USAGE.md) | 电流/速度/位置工况、参数覆盖与读波形 |

06–14各功能模块waveform_analysis另有run_<模块名>_validation.m薄入口，只运行本模块场景。没有新增顶层scripts或parameters目录。

第15步入口：

| 入口 | 用途 |
|---|---|
| [run_mtpa_fw_case.m](../../model/lib/MTPA弱磁/build_process/run_mtpa_fw_case.m) | 新组件/整机单次实验；自动刷新MTPA派生表，返回实际配置 |
| [run_mtpa_fw_validation.m](../../model/lib/MTPA弱磁/waveform_analysis/run_mtpa_fw_validation.m) | all / mtpa / fw / motor，分别7/11/7项 |
| [export_mtpa_fw_plots.m](../../model/lib/MTPA弱磁/waveform_analysis/export_mtpa_fw_plots.m) | 从已保存数据导出PNG/SVG |
| [MTPA/弱磁操作教程](../../model/lib/MTPA弱磁/build_process/USAGE.md) | 模型运行、参数覆盖、GUI临时参数与Scope |

[返回 docs](../README.md) · [返回工程入口](../../README.md)

第16步R2026b首批现有9个SLX和58项独立MIL：[启动搭建](../../model/lib/无感启动/build_process/build_sensorless_startup.m)、[启动10项验证](../../model/lib/无感启动/waveform_analysis/run_startup_validation.m)、[切换搭建](../../model/lib/无感切换/build_process/build_sensorless_handover.m)、[切换19项验证](../../model/lib/无感切换/waveform_analysis/run_handover_validation.m)、[实例搭建](../../model/lib/相位跟踪/build_process/build_pll_instances.m)、[实例验证](../../model/lib/相位跟踪/waveform_analysis/run_pll_instance_validation.m)、[PLL搭建](../../model/lib/相位跟踪/build_process/build_angle_tracking.m)、[PLL验证](../../model/lib/相位跟踪/waveform_analysis/run_angle_tracking_validation.m)、[基础SMO搭建](../../model/lib/观测器/滑模/build_process/build_sliding_mode_observer.m)、[SMO验证](../../model/lib/观测器/滑模/waveform_analysis/run_smo_validation.m)、[SMO波形重绘](../../model/lib/观测器/滑模/waveform_analysis/export_smo_plots.m)。

编译缓存清单为工程根SensorlessFieldWeakeningFOC.slxc及其slprj/sim/varcache内的checksumOfCache.mat、varInfo.mat和tmwinternal/simulink_cache.xml。删除文件后只移除空的5级父目录，保留其他模型或未知缓存。脚本按实际数量更新MANIFEST的3个统计字段。临时MRAS类型修复若存在，正式库、M源码及typed_verification.json必须已发布且匹配，才允许清理；这些检查也适用于-WhatIf。

## 受保护模型

[rebuild_protected_models.m](rebuild_protected_models.m) 在临时副本生成并回放受保护发布文件。配置与验证方法见[发布契约](../interfaces/PROTECTED_MODELS.md)。
