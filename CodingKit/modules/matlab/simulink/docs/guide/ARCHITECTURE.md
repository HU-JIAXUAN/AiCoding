# 模型组织与组合

工程顶层保留model与docs。model内分lib和app_models：lib保存复用积木与组件测试台，app_models先按Sensor/Sensorless分类，再按功能保存完整算法装配。

## 1. 文件归属

复用功能放model/lib/<module_name>；完整算法放model/app_models/Sensor/<module_name>或model/app_models/Sensorless/<module_name>。各功能的主模型和测试模型仍放自己的src。

每个模块包含：

| 位置 | 保存内容 |
|---|---|
| README.md | 模块用途、文件、接口、参数和验证入口 |
| src/ | 源模型与独立测试模型 |
| parameter/ | 默认值、输入、过程变量、输出和 Scope 通道说明 |
| build_process/ | 搭建步骤、计算原理、使用方法与过程模型 |
| waveform_analysis/ | 运行脚本、数据、图片和分析 |
| ref/ | 外部参考模型、资料和来源 |
| docs/ | README.md与公式推导.md，从原理到实际公式/状态/参数对应 |

工程级接口、运行入口说明和验证说明分别在 docs/interfaces、docs/scripts、docs/validation。其余工程文档直接在 docs 中维护。未来功能只列在建设计划，开始实现时再创建对应模块。

## 2. 模型如何组合

控制器根据给定和反馈计算命令；Plant 根据命令计算对象响应；组合模型负责连接两者并施加工况。每部分管理自己的状态、参数和测试。逻辑职责通过端口、单位、采样周期和复位定义区分，不要求额外的目录层级。

~~~text
给定 → 控制模块 → 执行/对象模块 → 反馈
          ↑                      │
          └──────────────────────┘
~~~

小模块优先用带清晰端口的 Library/Subsystem 复用；较大组件需要独立维护或构建时再用 Model Reference。有两个实际算法实现需要比较时，再加入 Variant。

控制模块不读取对象内部真值或 C2000 寄存器。对象真值供分析使用；实际采样和执行在对应装配模型中接入。多个模型引用同一源模块，避免复制后分别修改。

## 3. 参数与时序

每个模块在自己的 parameter 中维护默认值及信号说明。跨模块复用引用原定义；每次实验在结果中记录实际配置。统一约定见[接口说明](../interfaces/INTERFACE_CONTRACT.md)。

积分状态、滤波状态、使能、复位和限幅反馈都在模块中说明。PWM 频率、控制更新率与求解器步长分别确定；当前 PID 的 1 ms 是测试设置，电流环接入时重新设计。

## 4. 两个 C2000 目标

当前已有 P650 LaunchPad，后续使用自制 F28388D，先以 CPU1 为执行基线。控制算法按功能复用；板级采样、PWM、时钟和部署配置随对应实机装配模块实现。两个目标分别生成、构建和验证。

目标说明在 [F28P65X_TARGET_PLAN.md](../platform/F28P65X_TARGET_PLAN.md) 和 [F28388D_TARGET_PLAN.md](../platform/F28388D_TARGET_PLAN.md)。目前保留说明，未创建板级模型或代码目录。

## 5. 当前进度与下一步

已有PID与math；06–14八个模块新增45项MIL，原组合入口为[experiment](../../model/app_models/Sensor/experiment/README.md)，继续保留iq型速度环和52列记录。第15步新增[MTPA弱磁](../../model/lib/MTPA弱磁/README.md)：MTPAFWMotor引用原库，以TorqueStage输出N·m，再由Allocator分配id/iq，分配转矩残差反馈速度PI；25项MIL，74列记录。MTPA、弱磁状态和约束分配在同一功能模块内，积木归model/lib/MTPA弱磁，整机模型归model/app_models/Sensor/mtpa_fw。R2026b代码探路已生成CurrentPIProbeTest的C源码，见[记录](../validation/code_generation.json)；single/SIL及C2000目标验证仍待完成。

新增模块沿用同一目录格式，具体顺序见 [IMPLEMENTATION_PLAN.md](../plans/IMPLEMENTATION_PLAN.md)。模型、代码生成、目标构建/PIL 与实机各自保存验证结果。

第16步新增[相位跟踪](../../model/lib/相位跟踪/README.md)与[滑模](../../model/lib/观测器/滑模/README.md)，SMO通过库链接复用PLL，两者均有独立测试台，PLL另有实例隔离测试台，PLL/SMO独立共29项MIL。现已补充[无感启动](../../model/lib/无感启动/README.md)和[无感切换](../../model/lib/无感切换/README.md)，分别10/19项时序与相位工况；原四类lib共58项；新增HybridFusion独立30项后共88项，HFI↔基波物理整机组合继续实施。另已补齐电流PI坐标跟踪10项独立MIL；Sensor/observer_compare通过SMO库链接完成8项PMSM MIL，无输出回到控制。SensorlessFOC已完成8项物理PMSM MIL；EMF/EEMF32项、磁链24项独立MIL及HFI轴线/探针57项已完成。HFI位置启动22项、低速FOC24项App MIL另计，后者复用可复位SpeedProfile；HFI↔EEMF物理融合18项、MRAS24项、EKF25项、UKF29项及sigmoid22项独立验证已完成；EEMF/Flux在共同SPMSM基线各完成8项App MIL；凸极观测器组合、无位置弱磁和代码/目标验证继续。

[目录规则](../../rules.md) · [返回工程入口](../../README.md)

## 6. 当前路径与测试入口

公共initialize_motor_paths、initialize_motor_model、run_motor_case、run_motor_validation在docs/scripts，为测试和实验服务。App引用lib，库算法不读取App内部状态或Plant真值；组件测试的装配依赖单独处理。

第15步原始25项数据仍归档在lib/mtpa_fw/waveform_analysis，records.motor为整机记录；App波形页直接引用归档。迁移验证见[MODEL_LAYOUT_MIGRATION.md](../history/MODEL_LAYOUT_MIGRATION.md)。

## 7. App位置反馈分类

[Sensor](../../model/app_models/Sensor/README.md)保存使用位置/速度反馈的App，当前三个App为仿真反馈链；[Sensorless](../../model/app_models/Sensorless/README.md)保存用估算角度/速度控制的App，现有sensorless_foc与sensorless_hfi；后者含独立位置启动和低速闭环。分类按控制链实际采用的角度/速度来源；分析中记录对象真实角度不改变分类。两类共用lib，电流采样方式另在App参数中声明。

可复用观测器、角度跟踪、启动与切换积木归lib。Sensor可调用同一观测器并行对照，Sensorless将估算量接入控制；App只组合和配置，不维护算法副本。拟建模块与顺序统一见[无位置传感器计划](../plans/SENSORLESS_PLAN.md)，六类基波/启动库及HFI已有模型，暂未建立公共Bus对象。
