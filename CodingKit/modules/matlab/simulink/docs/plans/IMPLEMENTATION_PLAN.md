# 分步建设计划

状态：离散 PID 12项、math 13项；步骤06–14新增45项、步骤15新增25项MIL通过。小组件代码生成探路已在B通过编译分析并生成C，该探路未构建可执行程序或运行SIL；另完成代表性MRAS状态更新double/single MEX与double SIL。按步骤推进，不安排每日课程或固定学习时长。

| 步骤 | 要做什么 | 完成范围 |
|---|---|---|
| 01 | 整理架构、目录和 README | 已完成：顶层保留model与docs；model/lib保存积木，model/app_models按Sensor/Sensorless区分位置反馈，叶目录按功能划分 |
| 02 | 核对工程环境与目标 | 基础 Simulink 许可与入口已核对，可开始标准块建模；Coder/TI 工具链与实际板卡接入后续继续核对 |
| 03 | 固定接口与参数 | PID 首版接口、1 ms 周期、参数与复位已明确；电机单位/方向/参数在接入前完成 |
| 04 | 搭 PID/PI 基础积木 | 已完成首版[离散 PID](../../model/lib/离散并联PID/README.md)：限幅、回算、使能/复位，12 项 MIL 工况；后续代码验证继续穿插 |
| 05 | 搭基础数学模块 | 已完成 [math](../../model/lib/math/README.md) 的 Clarke/Park/InversePark/InverseClarke：幅值、方向、零序及独立反变换通过；滤波、角度处理与限制器后续按需补充 |
| 06 | 搭数学电机与负载 | 已建[永磁同步电机](../../model/lib/永磁同步电机/README.md)：dq电气与刚性机械，5项解析/能量/符号验证 |
| 07 | 建最小实验入口 | 已建[experiment](../../model/app_models/Sensor/experiment/README.md)：SimulationInput单轮覆盖，保存实际参数、输入与52列数据 |
| 08 | 闭合电流环 | 已建[电流环](../../model/lib/电流环/README.md)：双轴PI、最终电压残差回算，6项通过；CurrentPIProbeTest已在B临时副本生成GRT/C源码，SIL/目标构建待做 |
| 09 | 接 SVPWM 与平均逆变器 | 已建[逆变器](../../model/lib/逆变器/README.md)：共同分量注入、duty钳位、浮动中性点平均模型，4项通过 |
| 10 | 加采样与执行时序 | 已建[采样执行时序](../../model/lib/采样执行时序/README.md)：同步采样保持、反馈/执行整数拍延迟、100µs电流与1ms外环，3项精确拍数验证及整机延迟对照 |
| 11 | 加速度环与位置环 | 已建[运动环](../../model/lib/运动环/README.md)：速度PI复用旧PID、位置P、速度前馈端口及限速/速度斜率；R2026b原3项回归与新增SpeedProfile 8项测试通过 |
| 12 | 固化共同实验与指标 | experiment保存9个共同场景：理想/平均/含时序电流、额外延迟、反转、参数变化、限压恢复、禁能/复位；加载及补偿开关对照随各模块保存 |
| 13 | 加 dq 解耦与电压前馈 | 已建[电压前馈](../../model/lib/电压前馈/README.md)：5项符号、开关、同工况与失配对照，核对无虚假限制残差 |
| 14 | 加死区模型与补偿 | 已建[死区补偿](../../model/lib/死区补偿/README.md)：10项平均误差/平滑区对照及短时单桥臂开关、过零、短脉冲测试；不是完整三相器件F3模型 |
| 15 | 加 MTPA 与弱磁 | 已建[MTPA弱磁](../../model/lib/MTPA弱磁/README.md)：先MTPA，再电压需求辅助的有界积分弱磁；固定id下协调电流圆/电压区间，转矩残差回算速度PI，25项MIL |
| 16 | 搭无位置传感器基础并做观测器替换 | 按[专项计划](SENSORLESS_PLAN.md)推进：PLL、SMO、启动/切换、首个Sensorless闭环，再加EEMF/磁链/HFI；观测器归lib，App共用 |
| 17 | 主机数值/代码验证，C2000暂缓 | 已完成MRAS状态更新函数double/single MEX与double SIL；完整SLX/App的single与SIL未执行；按用户最新目标，本轮不执行C2000目标构建/PIL/板卡验证 |
| 18 | 实机对照与维护收口 | 核对 ADC/PWM/反馈、实际时序和基础闭环，整理模型与结果说明 |

当前已完成06–15的历史MIL模型与文档；第16步的[PLL](../../model/lib/相位跟踪/README.md)和[基础SMO](../../model/lib/观测器/滑模/README.md)连同[启动](../../model/lib/无感启动/README.md)与[切换](../../model/lib/无感切换/README.md)，现有R2026b的10个SLX、88项独立MIL（含新增双向融合30项）及完整参数/过程/Scope/波形资料。已补齐坐标跟踪PI 10项独立MIL和[Sensor并行对照8项](../../model/app_models/Sensor/observer_compare/README.md)完整PMSM MIL；SensorlessFOC三份SMO/EEMF/Flux App共完成24项物理MIL；EMF/EEMF及磁链库已分别完成32/24项，HFI轴线/探针57项、位置启动22项及低速FOC24项另计。HFI↔EEMF物理融合18项已完成，扩展观测器及40项物理App验证已完成。[专项计划](SENSORLESS_PLAN.md)按SL01–SL09列出后续清单。MRAS/EKF/UKF/sigmoid的独立lib及40项物理App接管验证已完成；第17步完成代表性MRAS主机MEX/SIL，完整App SIL/C2000暂缓。第15步结果见[模块入口](../../model/lib/MTPA弱磁/README.md)，06–14见[实施记录](../history/BUILD_06_14.md)。此前ConfigSetManager错误已随B补齐Simulink Coder后实际重跑解除，记录见[源码生成报告](../validation/code_generation.json)；观测器实际App接管40项已完成，代表性主机结果见[分析](../../model/lib/观测器/模型参考自适应/waveform_analysis/HOST_CODE_ANALYSIS.md)，完整App SIL未执行；C2000继续暂缓。

每步保留模型/配置、必要验证结果和简短说明。具体电机、功率级和反馈未知时单独记录待定，不影响目录整理；硬件验证保持待完成，不用仿真结果替代。

后续可选：模糊PI/ADRC、频响/辨识/自动整定、DOB/ESO、摩擦/齿槽/振动/双反馈、MTPV、预测控制、CLA/多核与HIL。无位置传感器主线和扩展观测器统一在专项计划维护，不再重复列为未安排的远期项。

第16步新增[凸极无位置弱磁App](../../model/app_models/Sensorless/sensorless_fw/README.md)：7项核心/9项边界，含2项反例；真实母线、物理负d、四象限回馈、旋转复位/方向事件与低EMF再启动均有独立记录，29Scope、六组日志、本地M参数和两份公式docs齐全。扩展观测器实际App接管40项已完成，代表性MRAS主机代码检查另存证，不以本项替代完整App SIL。

第16步扩展观测器已在共同物理SPMSM闭环新增40项App检查；[运行/参数](../../model/app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)随既有模块维护，不增加功能叶目录。第17步代表性MRAS状态更新主机检查已完成，完整App SIL/C2000未执行。

## 库发布维护

库 SLX 建立或修改后，按[受保护模型维护计划](PROTECTED_MODEL_PLAN.md)生成 `src/*.slxp`、核对接口和默认配置，再用 Model block 重放对应工况。
