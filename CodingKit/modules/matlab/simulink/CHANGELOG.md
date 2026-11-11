# Changelog

## Unreleased

- 清理脚本加入用户符号编辑缓冲的SHA256对比及未归档弱磁App检查；满足保留条件时停止整批清理，避免删除未归档修订和模型。 / Preserve unpublished symbol edits and staged FW output before cache cleanup.

- pmsm_plant新增运行时母线库PMSMBridgeBusPlant及Test，4输入/16输出，物理内核共用；10项检查（6正常/数值、4拒绝）通过，恒48/36V共672,056个物理输出数值与原桥差0。补齐本地M配置、34列/九组Scope、搭建/运行/三组波形与LaTeX推导，后续无感弱磁App将复用；未计为弱磁闭环、SIL或C2000验证。

- 工程目录统一为 `simulink/`，应用分类目录统一为 `model/app_models/`；README、规则、M 入口及验证记录同步新路径。库与 App 的 SLX 内容保持一致，目录检查和模型加载结果见 `docs/validation/directory_rename.json`。 / Rename the project and App directories and synchronize path references.

- 按用户要求卸载并重装官方MATLAB MCP v0.16.0及0.5.0配套包，重新注册到R2026b/new/nodesktop；发布哈希、136个Skill入口和新进程模型读写/检查/SMO短仿真通过。当前聊天旧transport已关闭，需重启Codex后复核；报告区分独立冷启动与聊天连接，未增加算法MIL或C2000验证计数。

- 按主参考书印刷VII–XIX页转录工程符号定义表，保留原符号、描述、单位和两页缩写；rules第13节将其设为符号依据，工程README/文档索引补入口，程序标识与单位换算在模块parameter中映射。

- sensorless_foc新增FlyingFluxFOC直接运行App，复用磁链观测和桥耦合PMSM，完成关断观察、持续资格、PI反电势跟踪准备与正反转同向接管。13项物理MIL和8组纯M通过，保留静止/反向目标/电压不足拒绝及高速被动整流；本地13份M、七组Scope/34+19+29列、三组波形和LaTeX推导齐全。旋转中复位/禁能不重置Plant，原模型与库实现保持不变；全工程现65份SLX，SIL和C2000验证继续。

- pmsm_plant新增PMSMBridgePlant库/Test，将线性电机磁链与平均PWM/关断二极管桥耦合；15项模型检查和18组纯M通过，包含480点独立电路条件核对、能量与步长收敛。13个本地M入口、七组Scope/33列、三组波形和LaTeX推导齐全；区间等效电压与当前电流分别说明。尚未接入旧App关断与带速捕获，原有模型保留。修正sensorless_foc README规定表头及分析六字段。

- sensorless_foc新增EemfSensorlessFOC和FluxSensorlessFOC两份可运行App，各8项物理MIL；共同SPMSM基线复用启动、电流/速度环和执行链，单独维护EEMF电流残差与Flux幅值等效残差。补齐本地M配置、5组Observer Scope、搭建/运行/波形和公式；当前M源重建及正式目录默认四组日志一致，原SMO模型保留。当前25个功能模块覆盖62份模型，凸极无位置弱磁、SIL和C2000验证继续。

- observer_smo新增sigmoid库/Test及本地M参数，原基础两份模型字节不变；22项MIL含11正常、10拒绝/故障及1个10mA噪声资格限制，原失败保留、门限未放宽。另有10项纯M、实例隔离、6次匹配对照及3组波形，源码重建与正式路径默认24列一致。当前25个lib/App功能模块均补齐docs/README与LaTeX公式推导，覆盖60份模型。

- 新增observer_ukf的库与Test模型，引用共享四状态SPMSM及KalmanMeasurement，以9点/圆周统计预测；29项独立MIL、21项数值、不同参数实例隔离及25同输入对照通过。记录本机官方对象中央协方差权重行为差异，使用公开公式与闭式矩核对；保存参数M、10组Scope、4组波形与计算量。重建和正式目录默认50列一致，尚未计为完整single/SIL或目标时序验证。

- 按用途固定模型命名：lib可按功能有多组库/验证模型，库不带Test，验证以Test结尾，App不带Test。MTPA/FW App更名MTPAFWMotor，代码生成验证入口更名CurrentPIProbeTest；默认输出分别核对1,900,077和2,107个数值完全相同，原28个lib Test模型字节不变，入口/参数/Scope路径与规则同步。

- 四状态SPMSM EKF完成25项独立MIL、完整协方差检查、相反速度分支合成反例及并行实例隔离；M源重建和正式目录默认50列/时间一致。补齐10组Scope、本地M参数、过程/运行/波形说明；共用过程在pmsm_plant维护，增加4+4个纯M偏导点核对。

- observer_emf新增LinearEMF/EEMF、两个测试台和32项正式路径MIL，3个SLX在src；复用PLL，通过已知方向/幅值/残差判断有效性，包含保持使能的零速和低速失效检查。保存参数M文件、四状态和前向Euler说明、6组Scope/22列、构建图和波形；尚未接入完整App。已有95项回归全部通过，MotorExperiment补本地全部参数组合入口并实际默认运行核对。

- 新增Sensorless/sensorless_foc，五个子系统复用lib，通过两段电压对齐、I-f、估算资格、同坐标参考混合及积分状态跟踪形成SPMSM无位置速度闭环。8项物理PMSM MIL通过，保存13/20/46/26列50 μs数据、16组Scope、搭建/调参方法和波形；失锁1 ms退出，电流对齐反例保留，未计为SIL或实机证据。

- 各模块parameter补齐可执行默认工况M文件，MTPA/FW App补独立参数组合入口；通用初始化从模块入口读取，不再重复写默认工况。13个测试台StopTime绑定本地参数并重新打开/运行核对，参数索引与rules同步。9个本次生成的旧格式自动备份已核对路径/哈希后清理，工作缓存继续保留至建模结束。

- math库新增BlendDQ及FrameBlendTest，先旋转启动参考到控制坐标再混合；源模型在src，两个场景/513个向量通过，物理坐标误差≤3.56e-15A，原变换13项回归通过。补齐7输入/1输出、参数、11列记录、3组Scope和波形，供无位置App共用。

- 新增Sensor/observer_compare App，复用SMO/PLL和Clarke库链接，监测分支无输出回控制。8项完整PMSM MIL通过，保存28+52列数据、三组PNG/SVG及模块文档；逐点核对0/1/2拍年龄，Rs偏差及观测器禁能/复位不改变原控制trace。

- 电流环共用库新增FrameTrackingPI，显式保存I/E/P/FF并分离当前电压与下一状态更新；新测试SLX放src，10项独立MIL及原电流环6项R2026b回归通过。补齐坐标/前馈转换公式、输入输出、30列数据、6组Scope与波形；实际无位置电机App衔接继续实施。复查R2026a目录、exe和卸载登记均不存在，保留原安装包。

- 新增sensorless_startup和sensorless_handover两类复用库及独立测试台，SLX均在模块src；显式状态、I-f软件场角、持续捕获、平滑包角混合、规划速度、相位创新与锁存退出分别记录。完成10+19项独立MIL，保存输入/参数/12或22列数据及PNG/SVG；整数采样点定义事件并核对记录输入，实际电机与PI状态衔接待App验证。

- 完成R2026a官方卸载并登记残留；B补齐Simulink Coder，CurrentPIProbeTest临时副本通过编译分析并生成GRT/C源码，保留原失败记录，未计为SIL。PLL增加实例配置Mask和独立测试模型，3项隔离验证及原PLL12/SMO14项回归通过，保存4列原始数据、参数与Scope说明。

- R2026b内配置用户级MinGW14.2，完成C/C++选择、官方MEX编译运行和独立新建MCP会话环境检查；保存报告并同步环境清单。当时Simulink Coder仅完成下载、R2026a卸载曾等待Windows管理员确认；其后安装/卸载结果见上方记录。SIL尚未执行。

- 使用R2026b Update 1搭建angle_tracking和observer_smo，4个SLX位于模块src，SMO通过库链接复用PLL；完成12+14项独立MIL，保存参数、搭建/使用说明、Scope/trace通道、原始数据及PNG/SVG。后续开发目标改为R2026b，产品安装和MCP切换记录单独维护；未接入Sensorless整机，也未验证代码/目标。

- 补充无位置传感器建设计划：10个拟建lib（角跟踪、SMO、EMF/EEMF、磁链、HFI、MRAS、EKF、UKF及启动/切换）和4个拟建App，按SL01–SL09逐步推进；明确观测器归lib、两类App共用，目前均未创建。同步总计划、索引、规则和接口/验证说明。

- 按转子位置反馈方式将两个现有整机App迁入app_models/Sensor，Sensorless保留后续估算角度/速度App入口；共用lib，更新回调、加载/验证脚本、规则和全部相关链接。

- 实际分开model/lib与model/app_models：10个复用功能模块及组件测试台进入lib，两个整机模型归App；公共测试初始化/运行脚本移到docs/scripts，同步24个模型回调、规则、索引和链接。分类README统一UTF-8。

- 新增model/mtpa_fw：先MTPA查表候选，再有界积分弱磁，统一固定id下的含Rs电压区间/电流圆/负id边界；独立组件与新转矩PI整机入口共25项MIL，保存25/74列原始数据、Scope说明和波形。速度PI回算分配转矩残差，弱磁保留上一拍实际电压需求与模型需求两路，并留0.2V调节裕量。
- 保留06–14原MotorExperiment、库及52列数据格式；同步第15步搭建/运行/参数/参考资料、工程接口与计划。验证范围为double MIL，未新增C2000部署结果。

- 按06–14新增八个功能模块：数学PMSM/机械负载、双轴电流PI、SVPWM/平均逆变器、采样执行时序、速度/位置环、dq前馈、死区补偿和共同实验。模型均在各自src，保留专属README、parameter、build_process、waveform_analysis、ref。
- 新增45项MIL并保存原始配置、输入、数据、通道名、指标与PNG/SVG；逐模块记录搭建过程、操作方法和全部Scope通道，整机记录52列。电流PI新增同评价点外部电压残差，速度PI复用既有PID；禁能/复位同时门控PI与FF。
- 保留CurrentPIProbeTest及GRT配置失败记录，原始错误为ConfigSetManager内部类不可解析；Embedded Coder产品与正确许可探测通过，没有生成C、构建或目标验证。同步建设清单、接口现状、参考记录和文件统计。

- 新建 model/math，src 中实现 Clarke/Park/InversePark/InverseClarke 可复用库与独立测试模型；采用幅值不变、d 轴对齐、rad 电角度，保留零序并支持独立反变换命令。
- 完成 13 项 MIL 工况、解析公式与手算锚点验证，10 项完整往返最大误差约 3.55e-15 A；保存参数/输入/20 列数据、五组 PNG/SVG 波形、四组 Scope 说明和搭建/操作教程，同步模型索引与建设清单。
- 简化为 model 与 docs 两个顶层目录；离散 PID 迁至 model/discrete_pid，复用库、控制器、Plant 和组合模型统一按模块归档。
- 撤掉 47 份重复或占位 README 及 48 个空规划目录；已有架构、C2000 目标、环境、计划和验证文档移入 docs 并减少中间层级，更新全部入口与统计；从新路径重新运行 12 项 MIL 工况通过。
- 参数说明统一到各模块 parameter/，移除顶层 parameters 占位目录；说明配置、输入、过程变量、输出和 Scope 通道，新增 DiscretePID 运行/调参教程，补充积分、滤波微分、回算与复位的逐块实现。
- 将 validation、scripts、interfaces 收入 docs，合并接口入口并更新相对链接、架构、规则与文件统计；移动参数目录后重跑 12 项 MIL 工况通过。
- 首模块统一为离散 PID，默认 Kd=0 作为 PI 使用；增加后向欧拉一阶滤波微分、Kd/Tf 和 x_d 端口，更名模块、模型与脚本并更新全部入口。
- 验证扩为 12 个工况：8 项官方 PI、2 项官方 PID 对照以及 2 项启停/复位；原 PI 的 9 项工况与修改前逐点比较，前八通道最大差值为 0。
- 实现 src/DiscretePID.slx 可复用离散 PID 库和 src/DiscretePIDTest.slx 测试模型，包含前向欧拉、限幅、回算、禁能/复位与积分诊断输出。
- 新增模块参数、模型工作区初始化、12 工况验证脚本、MAT/JSON 原始结果、五组 PNG/SVG 波形、搭建记录及模型图；8 项官方 PI 对照输出最大差值为 0。
- 同步首模块 README、工程与测试/参数索引、建设清单和 MANIFEST；当前验证为 double MIL，未进行 C2000 代码生成或实机验证。
- rules.md 只保留目录、文件名、记录字段和检查结果规则，增加薄 AGENTS.md 读取入口。
- 初始整理按功能建立 discrete_pid 模块目录及专属 README、src、搭建过程、波形分析、ref、参数目录，并同步参数索引与文件统计。
- 同步 simulink 当前目录与资料入口，移除已删除背景目录的过时说明；旧独立配置脚本转为 README 格式示意。
- 初始整理将离散 PID 及独立验证模型列为首模块。
- 整理为共用控制核、分级 Plant、采样/执行适配和实验分析四个主要边界，精简目录 README。
- 确认 P650 LaunchPad 为当前目标、自制 F28388D 为后续目标，新增两个适配目录与 C2000 工作流说明。
- 将实施顺序改为 18 个简单步骤，保留早期代码生成检查。

## [1.0.0-plan] - 2026-11-07
- 冻结模块化 PMSM FOC 仿真平台规划基线、统一接口草案、目录 README、路线图、测试矩阵、维护约定。
- 约定本包为计划文件，不代表 Simulink 模型已实现或已通过测试。
