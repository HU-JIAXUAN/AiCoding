# PMSM 模块化控制与仿真

所有模型统一放在[model/](model/README.md)，工程说明放在[docs/](docs/README.md)。已有离散PID、math；步骤06–14新增45项MIL，步骤15的[MTPA/弱磁](model/lib/MTPA弱磁/README.md)新增25项历史MIL。第16步新增R2026b的[PLL](model/lib/相位跟踪/README.md)与[基础SMO](model/lib/观测器/滑模/README.md)，连同[启动](model/lib/无感启动/README.md)和[切换](model/lib/无感切换/README.md)，四类lib现有10个SLX、88项独立MIL（含新增双向融合30项）；电流环新增[坐标跟踪PI](model/lib/电流环/README.md)测试台并通过10项独立MIL，[Sensor并行对照App](model/app_models/Sensor/observer_compare/README.md)通过8项完整PMSM MIL，同年龄参考核对及原控制不受观测器影响的比较均通过。B中代码生成探路已通过编译分析与C源码生成，未执行SIL或C2000验证，见[环境记录](docs/history/MATLAB_R2026B_MIGRATION.md)。

新增[HFI启动链](model/app_models/Sensorless/sensorless_hfi/README.md)：实测逆电感快照→轴线跟踪→双脉冲极性→恢复完整位置，共22项物理MIL；新增同模块HFI低速FOC24项物理MIL，复用可复位速度给定、电流PI和逆变器。HFI轴线30项、探针27项另计。同模块HFI↔EEMF物理双向融合新增18项MIL；12份日志、15组Scope、搭建过程与M参数随模型保存。新增[EEMF/Flux闭环App](model/app_models/Sensorless/sensorless_foc/README.md)各8项物理MIL，独立重建默认四组日志一致；其余观测器和App继续按[专项计划](docs/plans/SENSORLESS_PLAN.md)实现。

新增[四状态SPMSM UKF](model/lib/观测器/无迹卡尔曼/README.md)，29项独立MIL、21项纯M及不同参数并行实例通过；25个共同工况与EKF核对输入/公共参数相同，保存4组波形和计算量说明。M源重建与正式路径默认50列一致，本地M参数及10组Scope齐全；[UKF原理与LaTeX推导](model/lib/观测器/无迹卡尔曼/docs/README.md)已补齐。当前29个lib/App功能模块均有自己的`docs/README.md`和`docs/公式推导.md`，涵盖82份模型的功能分组、原理、实际公式、状态及参数对应。新增sigmoid SMO的库、Test、M参数和验证已落入[滑模](model/lib/观测器/滑模/README.md)。

新增[四状态SPMSM EKF](model/lib/观测器/扩展卡尔曼/README.md)，25项独立MIL、完整协方差、相反速度分支反例及不同参数并行实例检查通过；M源重建和正式路径默认50列一致，10组Scope、本地参数和运行资料齐全，批量运行后关闭模型/图窗。sigmoid分支已完成独立验证及10项物理App替换验证，代表性MRAS主机代码检查已完成，完整App SIL未执行。

新增[SPMSM电流模型MRAS](model/lib/观测器/模型参考自适应/README.md)，24项独立MIL及不同参数并行实例检查通过；参数、一步预测/PI状态、8组Scope与波形随lib维护。它不承担零速位置识别，已在共同SPMSM物理App完成10项接管/拒绝/退出检查，独立lib/App分别记录；状态更新函数另完成double/single MEX与double SIL，完整App SIL未执行。

新增[Sigmoid SMO](model/lib/观测器/滑模/README.md)：原基础库/Test继续保留，同一src新增独立库/Test。22项MIL包含11正常、10拒绝/故障和1噪声限制；10项纯M、双实例及6次匹配对照另计。独立源码重建和正式路径默认24列逐点一致，所有配置来自本地M，6组Scope及3组波形/推导齐全。

新增[磁链带速捕获App](model/app_models/Sensorless/sensorless_foc/build_process/FLYING_USAGE.md)：桥耦合PMSM在关断中观察实际端电压/电流，先准备PI积分，再同向接通PWM。13项物理MIL、8组纯M、七组Scope和三组波形齐全；保留反向目标/静止/电压不足拒绝及高速被动整流，不把关PWM等同于切断所有电流。

新增[凸极无位置MTPA/弱磁App](model/app_models/Sensorless/sensorless_fw/README.md)：EEMF使用物理端电压，分配器、SVPWM与物理桥共用真实母线；7项核心和9项边界检查通过（14正常/限制/拒绝＋2明确反例），默认210rad/s、真实id约−5.91A，双向回馈约−106.879W。新增本地M参数、六组日志、29组Scope、重启互锁、搭建/运行/LaTeX推导及波形；M重建与正式路径重放分别记录。四种扩展观测器实际App接管40项已完成；代表性MRAS主机代码检查已完成，完整App SIL/C2000暂缓。

## 符号约定

工程中的公式、接口、参数和Scope说明以[符号定义表](docs/userdocs/符号定义表.md)为准。该表按原书VII–XIX页保留符号、描述、单位及缩写原文；程序标识和工程单位的映射写在模块`parameter/README.md`，具体见[rules.md第13节](rules.md#13-工程符号约定)。

## 目录结构

~~~text
simulink/
├── docs/                         工程说明与公共测试脚本
└── model/
    ├── lib/                      共用积木和组件测试台
    ├── app_models/
    │   ├── Sensor/               使用位置/速度反馈
    │   │   ├── experiment/       原整机基线
    │   │   └── mtpa_fw/          MTPA/FW整机
    │   └── Sensorless/           无位置传感器App，已有sensorless_foc
    └── studies/                  学习、复现与第三方示例分析
~~~

复用积木进入[lib](model/lib/README.md)，组装后的完整算法进入[app_models](model/app_models/README.md)。App按位置反馈分Sensor/Sensorless，再按功能划分。当前Sensor中的位置反馈为仿真链路。模块内部格式见[rules.md](rules.md)。

## 从这里开始

所有已建模块的参数M文件入口、重新加载方法及单次实验示例见[参数使用索引](docs/guide/PARAMETER_USAGE.md)。[首个无位置闭环](model/app_models/Sensorless/sensorless_foc/README.md)已通过8项MIL；本轮观测器与App均已有实现和各自验证入口。

1. [离散 PID 模块](model/lib/离散并联PID/README.md)：模型、接口和验证入口。
2. [运行与调参](model/lib/离散并联PID/build_process/USAGE.md)：在 Simulink 中运行、修改参数和观察波形。
3. [参数与信号](model/lib/离散并联PID/parameter/README.md)：输入、过程变量、输出和九个 Scope 通道。
4. [搭建过程](model/lib/离散并联PID/build_process/STEPS.md)：积分、滤波微分、回算和复位的实现。
5. [分步计划](docs/plans/IMPLEMENTATION_PLAN.md)：后续逐项建设内容。
6. [简化架构](docs/guide/ARCHITECTURE.md)：模型归属与组合方式。

06–14入口：[实施记录](docs/history/BUILD_06_14.md)、[整机运行教程](model/app_models/Sensor/experiment/build_process/USAGE.md)、[整机52列与Scope](model/app_models/Sensor/experiment/parameter/README.md)、[共同实验分析](model/app_models/Sensor/experiment/waveform_analysis/ANALYSIS.md)。每个模块都保留README、src、parameter、build_process、waveform_analysis、ref和docs；模块docs只放README与公式推导两份Markdown。

## 建设方向

已有P650 LaunchPad，后续使用自制F28388D，先以CPU1验证。当前使用R2026b，[产品安装、Skill/MCP切换及R2026a卸载](docs/history/MATLAB_R2026B_MIGRATION.md)已完成。六类基波/启动库、Sensor并行对照和首个SensorlessFOC已验证，HFI位置启动22项及低速FOC24项物理MIL另计；HFI↔EEMF物理融合18项已完成，扩展观测器及物理App按[专项计划](docs/plans/SENSORLESS_PLAN.md)完成本轮MIL。第15步[运行教程](model/lib/MTPA弱磁/build_process/USAGE.md)、[Scope/74列说明](model/lib/MTPA弱磁/parameter/README.md)和[波形分析](model/lib/MTPA弱磁/waveform_analysis/ANALYSIS.md)随模块保存。旧MotorExperiment保留52列格式；MRAS状态更新主机MEX/SIL已完成；实际电机参数、完整App SIL和C2000构建/实机验证仍待完成。

主参考为 chensha，MBD 辅助参考。具体 C2000 工作流、目标计划和环境记录见 [docs/](docs/README.md)。模型仿真、代码生成、目标构建/PIL 和真实电机验证分别记录结果。

新增[MRAS/EKF/UKF/sigmoid物理FOC](model/app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)，共同SPMSM与实际桥电压/电流，每种10项共40项App MIL通过；各20个lib链接，Scope30/32/32/30，本地14M、六组日志与原理/波形齐全。M独立重建和布局前后默认六组数据一致，正式路径重放另存证；观测Rs+15%的Kalman速度偏差保留，不用valid代替真值误差。

当前目录`simulink`，应用目录`model/app_models`。src 共 82 份工程 SLX（29 库、35 Test、18 App），29 个功能模块，1 份用户 ref 另存。Math 的 [Clarke、Park 与 SVPWM](model/lib/math/src/README.md) 分子目录管理，外环模型位于 [速度环与位置环](model/lib/速度环与位置环/README.md)。[单关节 MIT Mode](<model/app_models/Mit Mode/README.md>) 与位置／速度控制支路共用 FOC 电流环。每模块有可执行参数 M 及两份公式文档。 [工程清单](MANIFEST.json) · [公式检查](docs/validation/formula_documentation.json) · [主机验证范围](model/lib/观测器/模型参考自适应/waveform_analysis/HOST_CODE_ANALYSIS.md) · [清理记录](docs/validation/cleanup.json)

新增[独立 I-f](model/app_models/Sensorless/sensorless_if/README.md)与[独立 V/f](model/app_models/Sensorless/sensorless_vf/README.md)。两个 App 各完成 13 项整机 MIL，共用 OpenLoopDrive 命令库与独立 Test（13 项 MIL）；[验证记录](docs/validation/if_vf_verification.json)分别保存构建、正式路径重放与结果，不并入历史观测器计数。

受保护模型共 44 份，覆盖 29 份库 SLX。按 [发布契约](docs/interfaces/PROTECTED_MODELS.md)核对接口、固定配置和验证环境。
