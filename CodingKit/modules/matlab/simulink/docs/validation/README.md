# 验证说明

2026-11-10按用户要求重新安装MATLAB MCP服务及配套包，发布哈希匹配，独立R2026b冷启动的模型读/写/检查和SMO 30ms仿真通过；136个Skill入口审计通过。当前聊天旧连接返回Transport closed，须重启Codex后再复核直接连接，见[重装记录](mcp_reinstallation.json)。本轮暂不执行C2000验证。

R2026b环境检查已完成：原清单47项产品全部可见，原清单及依赖54项登记，补装Simulink Coder后55项，Skill/MCP接口测试通过；独立临时工程副本完成121/121项MIL，见[环境记录](../history/MATLAB_R2026B_MIGRATION.md)、[安装清单](environment_installation.json)、[MCP接口验证](mcp_verification.json)和[121项回归报告](environment_regression.json)。

[Sensor并行对照App 8项](../../model/app_models/Sensor/observer_compare/waveform_analysis/ANALYSIS.md)完整PMSM MIL已通过：电压/电流/角度年龄逐点一致，Rs变化及禁能/复位观测器时原52列控制数据差为0；尚未接管控制。

[SensorlessFOC 8项](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/ANALYSIS.md)物理PMSM MIL已通过：六个健康工况在0.4901 s进入AUTO，另覆盖观测器1 ms失锁退出和电流对齐超时反例。16组Scope及四组统一50 μs日志随模块保存；本App尚未运行SIL或C2000实机验证。

[参数使用索引](../guide/PARAMETER_USAGE.md)登记本地M文件入口。[13个测试台绑定报告](parameter_binding.json)记录重新加载后实际GUI默认仿真终点与参数时长一致；这13项为参数入口检查，不重复累计为新的算法MIL场景。[清理记录](cleanup.json)记录已删除10个本次生成且哈希核对一致的旧格式自动备份；工作缓存最后清理。

[参数调整后的95项原有回归](parameter_regression.json)全部通过：PID12、math13、06–14模型45及MTPA/FW25。报告写出前MCP曾超过600 s等待上限，MATLAB实际继续运行并正常完成；没有重复启动整批回归。[MotorExperiment App参数入口检查](application_parameter_binding.json)另证明默认构造与原参数一致、模型工作区逐项一致及实际默认运行终点1.5 s。

[线性反电势/EEMF分析](../../model/lib/观测器/反电势/waveform_analysis/ANALYSIS.md)记录正式路径32项独立MIL及两个电机类型：正常估算、参数/噪声偏差、方向错误、实际反转、停用/复位及保持使能的零速/低速。独立轨迹32项保留；新增EEMF SPMSM闭环App另通过8项物理MIL，见[组合分析](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/OBSERVER_ANALYSIS.md)。

新增[坐标跟踪PI 10项](../../model/lib/电流环/waveform_analysis/FRAME_TRACKING.md)独立MIL及原电流环6项回归通过，正式src路径重新加载验证；尚未包含物理电机。原6项计为重跑，不重复累计新场景。

新增[启动10项](../../model/lib/无感启动/waveform_analysis/ANALYSIS.md)、[切换19项](../../model/lib/无感切换/waveform_analysis/ANALYSIS.md)独立MIL通过；含逐采样点时序、输入逐点一致、平滑包角与规划速度、短时失效及故障锁存。尚未记为电机闭环。

第15步[MTPA/弱磁分析](../../model/lib/MTPA弱磁/waveform_analysis/ANALYSIS.md)：25项MIL，MTPA7项、弱磁组件11项、整机7项；新入口记录25/74列。独立优化核对最小电流、检查可行点含Rs电压约束，覆盖四象限、退出、母线变化与不可达转矩回算。

模块的测试模型、测试脚本、数据和分析保存在本模块中。本目录维护工程级验证说明和报告格式。

| 文件 | 内容 |
|---|---|
| [TEST_MATRIX.md](TEST_MATRIX.md) | 单模块、闭环与目标验证范围 |
| [formula_documentation.json](formula_documentation.json) | 28个功能模块的两份docs、81份模型原生类型/导出块及LaTeX/来源核对；文档检查不新增MIL计数 |
| [METRIC_DEFINITIONS.md](METRIC_DEFINITIONS.md) | 指标计算口径 |
| [host_compiler.json](host_compiler.json) | MinGW14.2部署、MEX编译运行、新建MCP会话和后续Coder安装状态 |
| [old_release_uninstall.json](old_release_uninstall.json) | R2026a官方卸载结果和残留文件清单摘要 |
| [model_naming.json](model_naming.json) | lib库/验证与App命名检查；两项改名的逐点输出对照及哈希迁移 |
| [sigmoid验证](../../model/lib/观测器/滑模/waveform_analysis/sigmoid_verification.json) | 22项MIL、10项纯M、实例隔离、6次对照、源码/正式路径一致及31份源/产物哈希 |
| [EEMF/Flux组合验证](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/observer_foc_verification.json) | 两份新App各8项物理MIL，参数/Scope、当前M源重建、正式路径默认四组日志一致及源/产物哈希 |
| [桥耦合对象验证](../../model/lib/永磁同步电机/waveform_analysis/bridge_verification.json) | 15项模型、18组纯M/480点电路核对；7组Scope/33列、源/正式路径重放及26份源/产物哈希，尚未接入旧App |
| [带速物理App](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/flying_verification.json) | 13项物理MIL、8组纯M；8处共享链接、七组Scope、34/19/29列、当前M重建及正式路径校验；3类捕获拒绝与被动整流保留 |
| [code_generation.json](code_generation.json) | CurrentPIProbeTest源码探路与MRAS状态更新MEX/SIL，分开登记范围 |
| [RELEASE_GATES.md](RELEASE_GATES.md) | 各阶段需要的验证结果 |
| [EXPERIMENT_REPORT_TEMPLATE.md](EXPERIMENT_REPORT_TEMPLATE.md) | 实验报告字段 |

当前已运行结果见 [DiscretePID 分析](../../model/lib/离散并联PID/waveform_analysis/ANALYSIS.md)，运行入口见[模块使用教程](../../model/lib/离散并联PID/build_process/USAGE.md)。

[Math 变换分析](../../model/lib/math/waveform_analysis/ANALYSIS.md)记录 13 项工况，包含 10 项完整往返、独立反变换和丢弃零序的预期误差演示；幅值误差容差为 1e-12 A，平方和关系单独使用 A² 单位。

[返回 docs](../README.md) · [返回工程入口](../../README.md)

06–14新增45项MIL全部通过。入口为[run_motor_validation.m](../scripts/run_motor_validation.m)，各模块各存MAT、JSON与分析，汇总见[BUILD_06_14.md](../history/BUILD_06_14.md)。当前依据是解析响应、能量、精确拍数、限制/复位断言、同工况FF/死区对照；没有原始demo/官方块的整机逐点等价证明。

CurrentPIProbeTest在A中的配置失败保留于[codegen_probe.json](../../model/lib/电流环/waveform_analysis/codegen_probe.json)。补齐B的Simulink Coder后，在临时副本中重跑同条件配置，编译分析和C源码生成通过，见[新报告](code_generation.json)；未构建可执行程序、未运行SIL。single、目标构建/PIL与实机仍待验证。PLL独立实例新增3项MIL，原12项PLL/14项SMO重跑通过，见[实例分析](../../model/lib/相位跟踪/waveform_analysis/INSTANCES.md)。

凸极无位置弱磁App：独立[核心7项](../../model/app_models/Sensorless/sensorless_fw/waveform_analysis/guarded_core/fw_core_results.json)、[边界9项重分析](../../model/app_models/Sensorless/sensorless_fw/waveform_analysis/edges/edge_reanalysis_results.json)、[29组Scope/原生链接](../../model/app_models/Sensorless/sensorless_fw/waveform_analysis/fw_native_inventory.json)、[M重建](../../model/app_models/Sensorless/sensorless_fw/waveform_analysis/fw_rebuild_verification.json)和[波形说明](../../model/app_models/Sensorless/sensorless_fw/waveform_analysis/ANALYSIS.md)各自登记；原始错误末速度检查与波形保留，不重复计数同数据重分析。

扩展观测器物理App：[40项分析](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/EXTENSION_ANALYSIS.md)及各算法results.json保存20跟踪/8退出/12拒绝；[14M重建](../../model/app_models/Sensorless/sensorless_foc/waveform_analysis/extension_rebuild_verification.json)与布局前后默认轨迹分别核对，正式路径重放另存证。不把App40项并入lib301项。

[路径入口检查](model_paths.json)确认20个lib、8个App功能目录及76份工程模型可定位，另有1份ref模型不加入路径；[符号与参数检查](symbol_alignment.json)确认26模块的本地参数入口、五类说明栏目和原书/SI映射。52份说明文档调整，395份M/SLX字节保持，用户符号表保持；公式与链接检查不计为新增MIL。

[MRAS类型/主机验证](../../model/lib/观测器/模型参考自适应/waveform_analysis/typed_verification.json)通过double/single MEX与double SIL，2001点，SIL最大相对状态误差4.0856×10⁻¹⁴；原24项lib/10项App重放逐点一致。覆盖状态更新M函数，完整SLX/App single与App SIL未执行。[最终环境](final_environment.json)核对实际R2026b、附加组件、编译器、YALMIP和旧A目录；[当前实现指纹](current_implementation.json)在类型修正后更新，历史报告的原始指纹保留。

[独立 I-f/V/f 验证](if_vf_verification.json)记录公用命令 13 项、[I-f](../../model/app_models/Sensorless/sensorless_if/waveform_analysis/ANALYSIS.md) 13 项和 [V/f](../../model/app_models/Sensorless/sensorless_vf/waveform_analysis/ANALYSIS.md) 13 项 MIL，以及对象半步长和正式路径逐点重放。完整数据用于评分；仅保存两组浏览 CSV/图及全部小型指标，无新增 MAT。

[离散并联 PID 抗积分饱和对照](ANTI_WINDUP_COMPARISON.md)记录参考 demo 原始接线与连续仿真、同限幅离散对照及增益换算。

[受保护模型验证](protected_model_contracts.json)记录 44 份发布文件的端口、重放和 SHA-256，覆盖 29 份库 SLX。两种 SVPWM 的受保护模型各重放 14 组输入，4 路输出均与可编辑库一致。 [SVPWM 对照测试](../../model/lib/math/src/svpwm/README.md)
