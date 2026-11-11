# 模型目录迁移记录

## Sensor与Sensorless分类追加记录

2026-11-08：现有experiment、mtpa_fw两个完整App已迁入model/app_models/Sensor；Sensorless只保留分类README，暂无已实现模型。分类按控制实际使用的位置/速度反馈来源，当前Sensor App使用仿真反馈链。电流采样方式在具体App中另行说明，两类共用lib。

同步更新了两个App的PostLoadFcn（新增一层目录）、initialize_motor_paths、MTPA/FW单次入口、共同验证运行器的读取/结果保存路径及App验证薄入口。所有相关README、运行示例、规则和链接同步。

本轮在MATLAB R2026a从新路径验证3个入口：MotorExperiment为15001×52、1.5s；MTPAFWMotor为20001×74、2s，末点218.0000013rad/s；CurrentReferenceTest为2501×25、0.25s。均为有限数据，两个整机结构检查通过；34个MATLAB文件Code Analyzer为0提示。原始测试范围为路径迁移验证，不将此前全部MIL场景记为本轮重跑。数值与实际模型路径见[sensor_layout_metrics.json](sensor_layout_metrics.json)。

lib内22个SLX均与本轮迁移前逐字节一致；比较全部24个模型的系统XML，排除窗口及Scope显示缓存后，算法块参数和连接全部一致。两个App仅修改加载回调，未复制或修改通用库算法。

本轮DocSync、依赖治理、governance lint、Plan路径检查、Markdown本地链接、清单统计及git diff --check通过，链接为0错误。仓库Full结果为70通过、1失败、4跳过，Go单元测试、race和Staticcheck均通过；唯一失败为HEALTH-001，原因仍为现有visio-mcp/ppt-mcp同名未托管条目、runtime Skill漂移，以及相应命令超过延迟预算。报告位于仓库test-results/aicoding-global-test-20261108-224958/report.md。本轮没有修改工具安装或放宽门禁。

本轮迁移前文件快照及移动清单保留于：
C:/Users/24322/AppData/Local/Temp/simulink-sensor-layout-1794174071164/before.zip

以下为此前lib/App分离的记录；当前路径以本节和分类README为准。

日期：2026-11-08。按照model/lib与model/app_models中的README意图，将复用积木和完整算法装配分开。

## 目录与文件归属

| 内容 | 当前路径 |
|---|---|
| 10个复用功能模块与组件独立测试台 | model/lib/<module_name>/ |
| 原整机基线 | model/app_models/Sensor/experiment/src/MotorExperiment.slx |
| MTPA/FW整机 | model/app_models/Sensor/mtpa_fw/src/MTPAFWMotor.slx |
| 公共测试路径初始化 | docs/scripts/initialize_motor_paths.m |
| 公共模型初始化与单次实验 | docs/scripts/initialize_motor_model.m、run_motor_case.m |
| 06–14共同验证运行器 | docs/scripts/run_motor_validation.m |

各功能仍保留README、src、parameter、build_process、waveform_analysis和ref；SLX放各自src。两个分类README已统一为UTF-8。原始数据不复制或改写，第15步共同归档仍在lib/mtpa_fw/waveform_analysis，App页面直接链接其records.motor。

## 已验证

- 24个SLX从新位置加载成功，库链接解析至model/lib。
- 14个仿真入口默认工况全部运行，输出为有限数值，结果维数与末时刻见[migration_metrics.json](migration_metrics.json)。
- MotorExperiment为15001×52、1.5s；MTPAFWMotor为20001×74、2s，末点机械速度218.0000013rad/s。
- 34个MATLAB文件Code Analyzer为0提示。
- 12个未改回调的模型文件与迁移前逐字节一致；其余12个改动了加载回调。逐一比较24个SLX的系统XML，剔除窗口Open和Scope图形显示缓存/坐标轴状态后，所有算法块参数和连接一致。本次未改变控制算法。
- 导航、运行示例、规则、架构及建设计划同步；各模块原验证结果继续作为原始记录，不将14个默认入口检查称为95项场景重跑。

## 仓库检查

DocSync、依赖治理、Markdown本地链接与git diff --check通过。链接检查为0错误，无编码跳过项。Full报告位于仓库test-results/aicoding-global-test-20261108-215619：68通过、2失败、4跳过。HEALTH-001仍报告工具环境漂移及延迟预算问题；GO-001中TestFailedNodeDoesNotPublishReceipt在临时报告目录rename时遇到Windows Access denied。随后单独复查该用例已通过（4.108s），未修改Go实现或绕过门禁；原Full报告保留其失败结果，不改写为全通过。

## 备份与回滚边界

迁移前完整文件快照保留在：
C:/Users/24322/AppData/Local/Temp/simulink-layout-1794170613713/before.zip

仅备份本simulink目录。恢复时先解压到独立目录比较，再按本记录的路径归属恢复；不要直接覆盖后续用户修改。原目录与新目录的移动清单随备份保留。

## MATLAB安装状态

下载包为F:/Downloads/matlab_R2026b_Windows.exe，MathWorks数字签名有效；解压元数据为R2026b Update 1。当前仍为C:/Program Files/MATLAB/R2026a中的R2026a Update 3。setup.exe启动返回“操作已被用户取消”，尚未安装R2026b，原安装目录和安装包均未删除。目标路径的具体含义仍待用户答复；跨版本不能直接安装进含旧版本的目录。
