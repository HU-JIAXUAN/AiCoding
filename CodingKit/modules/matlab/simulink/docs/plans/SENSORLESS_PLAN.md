# 无位置传感器模型建设计划

状态：前六类库共17个SLX、166项独立MIL，含新融合积木30项。HFI轴线/正交探针新增3个SLX、57项MIL；实测均值和双脉冲已在[HFI启动App](../../model/app_models/Sensorless/sensorless_hfi/README.md)完成22项物理组合MIL，新增同模块HFI低速FOC完成24项物理MIL。已有电流PI坐标跟踪10项、Sensor并行对照8项、SensorlessFOC 8项另计；运动给定8项不计入观测器数量。新增HFI↔EEMF物理整机融合18项MIL；MRAS另已完成24项独立MIL；四状态EKF完成25项独立MIL、完整P和并行实例检查；UKF已完成29项独立MIL、21项纯M及并行实例/25同输入对照，sigmoid SMO新增2个SLX/22项MIL、10项纯M、实例隔离及6次匹配对照，原高噪声资格限制保留；另新增EEMF/Flux两份App各8项物理闭环MIL（不计入lib独立301项）；主线接[总计划](IMPLEMENTATION_PLAN.md)步骤16，不按天安排。

新增[pmsm_plant桥耦合对象](../../model/lib/永磁同步电机/README.md)及独立Test，15项模型/18组纯M验证关断、整流与主动短路；新增[磁链带速App](../../model/app_models/Sensorless/sensorless_foc/build_process/FLYING_USAGE.md)13项物理MIL和8组纯M，完成正反转同向接管、旋转中复位/禁能再捕获及失锁关断，并保留静止/反向目标/电压不足拒绝和高速被动整流。它不计入301项观测/启动库MIL；旧三份启动App未换物理对象，凸极无位置弱磁已完成16项独立App检查（含2反例）；四种扩展App40项已完成，代表性MRAS主机代码检查完成，完整App SIL/C2000暂缓。

本轮执行范围已确认为本页全部10类lib、改进SMO以及4个App。顺序为：R2026b产品/Skill/MCP检查 → 卸载R2026a → 补齐lib及独立验证 → 组装App及闭环验证 → 保存文档和结果 → 执行本次缓存清理。现有文件格式继续按rules.md维护。主要理论参考为本地《永磁同步电机无位置传感器控制》，章节、页码及lib/App采用内容见[书籍设计核对](../references/BOOK_SENSORLESS_DESIGN.md)；其他来源见[资料索引](../references/REFERENCE_SENSORLESS.md)。

## 1. 模型放在哪里

- 可复用观测器放model/lib/<module_name>/，包括其独立测试台、参数、搭建过程、波形和参考资料。
- 角度跟踪、启动和切换等通用积木也放lib；App负责具体电机、限值、连接和工况。
- Sensor/observer_compare计划用于并行估算：控制仍使用位置反馈，观测器只做对照，所以归Sensor。
- Sensorless中的闭环App用估算角度/速度控制，并继续引用同一套lib，不复制观测器实现。
- 未来模块先在本计划登记，开始实现时再创建目录；每个功能模块遵守[rules.md](../../rules.md)，SLX放src，参数和Scope说明放本模块parameter。

## 2. 要补的lib清单

前六项已实现17个SLX、166项独立MIL；HFI轴线/正交探针3个SLX、57项MIL，极性积木另有启动App22项组合验证，HFI低速FOC App24项另计。其余为拟用目录/模型名，不生成占位链接。

| 批次 | 拟建lib目录 | 拟建主模型 | 内容和验证重点 | 状态 |
|---|---|---|---|---|
| 首批 | [相位跟踪](../../model/lib/相位跟踪/README.md) | [AngleTracking.slx](../../model/lib/相位跟踪/src/AngleTracking.slx) | 相位PLL、包角误差、正反转和低幅值有效性 | 已实现，原12项及实例隔离3项MIL |
| 首批 | [滑模](../../model/lib/观测器/滑模/README.md) | [SlidingModeObserver.slx](../../model/lib/观测器/滑模/src/SlidingModeObserver.slx) | 基础边界层SMO、滤波/相移处理、SPMSM与方向失效 | 基础14项独立MIL保留；sigmoid新增22项（11正常、10拒绝/故障、1噪声限制）；Sensor并行对照8项使用基础版 |
| 首批 | [无感启动](../../model/lib/无感启动/README.md) | [SensorlessStartup.slx](../../model/lib/无感启动/src/SensorlessStartup.slx) | 对齐、I-f爬升、方向、接管与超时；输出软件场角和电流请求 | 已实现，10项独立MIL；SensorlessFOC另已完成8项起转/闭环MIL |
| 首批 | [无感切换](../../model/lib/无感切换/README.md) | [SensorlessHandover.slx](../../model/lib/无感切换/src/SensorlessHandover.slx) | 持续资格、平滑包角过渡、规划速度、预测与失锁退出；PI跟踪由电流环接入 | 原Handover19项及新增HybridFusion30项独立MIL；SensorlessFOC另已验证单向接管的电流/转矩与执行电压衔接，双向物理App另完成18项MIL |
| 第二批 | [反电势](../../model/lib/观测器/反电势/README.md) | [EmfObserver.slx](../../model/lib/观测器/反电势/src/EmfObserver.slx) | 线性反电势/Luenberger形式与扩展反电动势EEMF；显式区分SPMSM和IPMSM模型 | 已实现，3个SLX、32项独立MIL |
| 第二批 | [磁链](../../model/lib/观测器/磁链/README.md) | [FluxObserver.slx](../../model/lib/观测器/磁链/src/FluxObserver.slx) | SPMSM磁链、积分初值/漂移、直流去除和相位补偿；凸极扩展另行推导 | 已实现，2个SLX、24项独立MIL及开关反例 |
| 第二批 | [高频注入](../../model/lib/观测器/高频注入/README.md) | [HighFrequencyObserver.slx](../../model/lib/观测器/高频注入/src/HighFrequencyObserver.slx) | 实测张量资格、轴线解调/双角PLL、均值校准和双脉冲 | 轴线30项、探针27项MIL；极性启动App22项、低速FOC24项另计；物理双向融合另完成18项MIL |
| 扩展 | [模型参考自适应](../../model/lib/观测器/模型参考自适应/README.md) | [MrasObserver.slx](../../model/lib/观测器/模型参考自适应/src/MrasObserver.slx) | SPMSM上一拍实测电流的一步模型、归一化PI与资格 | 已实现，2个SLX、24项独立MIL及并行实例检查；物理App另有10项检查 |
| 扩展 | [扩展卡尔曼](../../model/lib/观测器/扩展卡尔曼/README.md) | [EkfObserver.slx](../../model/lib/观测器/扩展卡尔曼/src/EkfObserver.slx) | 共用四状态SPMSM过程、Joseph校正、完整协方差与角变化率资格 | 已实现，2个SLX/25项独立MIL；2项合成分支反例及并行实例另计，物理App另有10项检查 |
| 扩展 | [无迹卡尔曼](../../model/lib/观测器/无迹卡尔曼/README.md) | [UkfObserver.slx](../../model/lib/观测器/无迹卡尔曼/src/UkfObserver.slx) | 与EKF共用过程/测量，9点预测、圆周统计、完整协方差与有界修复 | 已实现，2个SLX/29项独立MIL；21项纯M、并行实例及25同输入对照另计，目标耗时未测 |

EEMF是Extended EMF；TI的eSMO是增强滑模观测器，两者不合并成一个算法名称。线性/Luenberger反电势观测与EEMF作为observer_emf内的不同实现；基础SMO与改进SMO作为observer_smo内的不同实现。

电压重建先复用并按需完善现有[逆变器](../../model/lib/逆变器/README.md)、[采样执行时序](../../model/lib/采样执行时序/README.md)、[死区补偿](../../model/lib/死区补偿/README.md)，不另造一份调制/执行链。滤波和包角的无状态算术按需复用或补入[math](../../model/lib/math/README.md)。EKF/UKF等矩阵算法可采用MATLAB Function，状态、离散更新和复位仍需说明清楚。

## 3. 按什么顺序搭

| 步骤 | 要做什么 | 本步产物/检查 |
|---|---|---|
| SL01 | 固定观测器输入和对照工况 | 复用Sensor基线；准备SPMSM的Ld=Lq测试覆盖与IPMSM覆盖，不改已有默认参数；明确电流样本对应的实际作用电压/时间区间 |
| SL02 | 搭angle_tracking | 已完成：解析相位、加减速、包角、反转、噪声、低幅值、禁能/复位共12项MIL |
| SL03 | 搭基础SMO及Sensor并行对照 | 已完成独立SPMSM测试14项和Sensor/observer_compare 8项完整PMSM MIL；估算仅对照，不接管控制 |
| SL04 | 搭启动和切换，闭合首个Sensorless FOC | 启动10项、切换19项、坐标状态跟踪10项和参考混合2场景已完成；SensorlessFOC另已完成8项物理PMSM MIL，检查实际电流、转矩、混合电压和失锁过程 |
| SL05 | 加EEMF与磁链观测器 | 共同SPMSM基线已新增EEMF/Flux两份App，各8项整机MIL；EEMF凸极IPMSM整机已在无位置MTPA/弱磁App完成16项核心/边界检查，磁链当前仍限SPMSM |
| SL06 | 加HFI与初始位置/低速控制 | 轴线30项、探针27项、校准/双脉冲App22项及低速FOC24项已完成；已补齐HybridFusion的重叠区、双向资格/退出、π重接和注入撤除/恢复30项独立MIL，按书5.9完成物理整机组合18项MIL，含实际电流/转矩、状态坐标转移和反转；保持实际电流响应、ADC和运动边界 |
| SL07 | 接MTPA/弱磁及更完整工况 | 桥耦合SPMSM带速捕获13项保留；新增同模块运行时母线桥库/Test通过10项检查，可用于实际母线阶跃。凸极[EEMF+MTPA/弱磁App](../../model/app_models/Sensorless/sensorless_fw/README.md)已完成高速限压、物理负id、正反转回馈和实际母线阶跃；7项核心＋9项边界检查含2项反例，旋转复位/重使能先观察再允许对齐。没有沿用Sensor结果；不执行任意高速带速接管 |
| SL08 | 扩展MRAS、EKF、UKF与改进SMO | MRAS24项、EKF25项、UKF29项独立MIL及各自实例检查已完成；UKF另有21项纯M与25同输入/参数对照，保存计算量及本机参考差异。已按12.3.3实现sigmoid分支，22项MIL及10项纯M/实例隔离/6次同输入对照；四种扩展观测器物理App已新增40项，代表性MRAS主机代码检查完成；完整App SIL/C2000未执行 |
| SL09 | 主机数值与代码验证；C2000暂缓 | 已完成MRAS状态更新M函数double/single MEX与double SIL及原24项lib/10项App回归；完整SLX/App的single与SIL未执行；按用户最新范围，本轮不进行C2000目标构建、PIL或板卡验证，恢复时再单独登记 |

SL01–SL05是首批主线；SL06–SL08本轮全部实现和验证已完成。SL09接总计划步骤17，CurrentPIProbeTest在B仅生成C源码；MRAS状态更新函数另完成代表性主机MEX/SIL，两者分开登记。按用户最新目标，本轮暂不执行C2000验证；P650/F28388D保留为后续平台。本计划不将许可可见或MIL通过记成代码/目标验证。

## 4. 拟建App

| 分类/拟用功能目录 | 作用 | 首版实现范围 | 状态 |
|---|---|---|---|
| [Sensor/observer_compare](../../model/app_models/Sensor/observer_compare/README.md) | 观测器并行估算及调参 | 位置反馈继续控制，SMO只分析；核对电压/电流/参考年龄和原控制不受影响 | 已实现，8项PMSM MIL |
| [Sensorless/sensorless_foc](../../model/app_models/Sensorless/sensorless_foc/README.md) | 共用无位置FOC对照入口 | 三份启动App＋桥耦合Flux带速App，观测器仍共用lib | 原24项＋带速13项＋扩展40项物理MIL；带速另8组纯M，凸极弱磁在sensorless_fw另计16项 |
| [Sensorless/sensorless_hfi](../../model/app_models/Sensorless/sensorless_hfi/README.md) | 零低速与中高速组合 | HFI/极性启动、低速FOC及基波双向融合 | 启动22项、低速FOC24项、物理融合18项MIL |
| [Sensorless/sensorless_fw](../../model/app_models/Sensorless/sensorless_fw/README.md) | 凸极无位置高速扩速 | EEMF＋MTPA/FW＋实际母线物理桥＋低EMF启动互锁 | 7项核心、9项边界，2项明确反例；M重建与正式重放另存证据 |

| [Sensorless/sensorless_if](../../model/app_models/Sensorless/sensorless_if/README.md) | 独立 I-f | 虚拟 dq PI、软件角度、实际桥与SPMSM | 13 项 MIL，含带速拒绝与失步反例 |
| [Sensorless/sensorless_vf](../../model/app_models/Sensorless/sensorless_vf/README.md) | 独立 V/f | V/f 电压律、软件角度；参考用户 demo | 13 项 MIL，含低母线与过载反例 |

共用 [OpenLoopDrive](../../model/lib/无感启动/README.md) 及 Test 完成 13 项独立 MIL；两套 App 先各自跑通，需要接闭环时再对接 handover 与观测器。

初期通过更换库块或明确的模型配置做离线对照；有两个真实实现且需要批量对照时，再按[Variant约定](../guide/VARIANT_POLICY.md)加入变体。启动到闭环的切换属于sensorless_handover，不等同于任意算法运行中无缝替换。

## 5. 共用接口、Scope与验证

PLL和SMO的实际端口已分别登记在[PLL参数页](../../model/lib/相位跟踪/parameter/README.md)、[SMO参数页](../../model/lib/观测器/滑模/parameter/README.md)，未创建公共Bus。其余算法仍为计划语义。普通观测器典型输入为i_alpha/i_beta（A）、u_alpha/u_beta（V）、enable/reset及电机/周期参数；本版SMO另有direction端口。接入App时电压必须来自最终作用电压重建或测量，并处理执行延迟/死区。不得把限幅前PI请求直接当作已经施加的电压。本版i_hat[k]与i[k]比较，u[k]对应[kTs,(k+1)Ts)区间并用于下一状态。

共用输出为theta_e_hat（电角rad）、omega_e_hat（带符号电角rad/s）及valid；机械速度由omega_e_hat/PolePairs得到。EMF/磁链/电流估计、残差等诊断量随算法输出。HFI另有注入请求/解调时序，启动器另有启动电流请求，EKF/UKF另有协方差等参数，不强行塞进万能端口表。

| 测试层次 | 检查内容 |
|---|---|
| 独立积木 | 解析信号、初值偏差、禁能/复位、包角、反转、低幅值和无效输入；记录实际使用的离散方法 |
| Sensor并行对照 | 估算器不消费真实角度；对齐数据年龄后记录包角角误差、速度误差、观测残差和valid |
| Sensorless闭环 | 启动、捕获和切换电流/转矩突变、正反转、负载、母线、饱和、丢样与失锁；真实角度只用于评估 |
| 参数/数值对照 | Rs/Ld/Lq/磁链误差、ADC偏置、噪声和延迟；只在算法共同适用工况下作性能比较 |
| 主机代码；目标暂缓 | double对single及适用的主机SIL；C2000构建、PIL、内存/执行时间与板卡结果本轮不执行 |

计划Scope按单位分组记录：估算/真实电角度与包角误差、估算/真实速度、电流与残差、反电势或磁链、实际电压与限制、valid和启动/切换状态；HFI另记录注入和解调响应。具体通道顺序、源块、单位及数据列在建模时写入该模块parameter/README，不能把本列表当成已有Scope。

valid应由幅值、残差、输入有效性等可测信息产生，不能用Plant真实角度误差在线判锁。指标保存计算窗口；角误差使用atan2(sin(delta),cos(delta))，同时记录丢锁次数/持续时间、捕获时间及速度/电流误差。阈值随首个明确电机工况写入parameter，不在计划里虚设全电机通用数值。

## 6. 实现前要明确的边界

- 基础SMO先用SPMSM验证，不能把单一L公式直接作为IPMSM实现。当前默认Ld≠Lq，基础验证用单次参数覆盖建立Ld=Lq工况。
- 常规基波反电势估算不直接保证静止位置识别；启动、零低速与带速捕获分别处理。
- PLL是相位跟踪积木；解析相位输入下PLL测试通过，不表示已经由电压/电流估出了转子位置。
- HFI的凸极轴估计存在π歧义；现有非线性高频Plant已支持双脉冲极性与低速FOC测试，常参数线性Plant仍不能证明依赖磁饱和的极性辨识。高低速融合恢复HFI时，需要重新核对分支和资格。
- 角度包角混合不能单独保证切换平顺，还要检查电流坐标、PI状态和电压命令的连续性。
- 首批验证以速度/转矩闭环为目标；不把估算电角度直接当成高精度多圈机械绝对位置。
- TI FAST/eSMO用于官方参考/后续对照。接入时核对F28P65X与F28388D各自SDK、库、许可和接口，不预先认定二者都能直接调用同一FAST实现。

## 7. 参考资料

本地主要书籍及实际采用内容见[书籍设计核对](../references/BOOK_SENSORLESS_DESIGN.md)。下面公开资料作补充，不表示本工程已实现其示例。现有模型使用R2026b；自建模型与官方块对照时先统一SI/标幺、角度和速度定义。

| 资料 | 用途 |
|---|---|
| [MathWorks：SMO](https://www.mathworks.com/help/mcb/ref/slidingmodeobserver.html) | 基础SMO模型和适用电机 |
| [MathWorks：Extended EMF Observer](https://www.mathworks.com/help/mcb/ref/extendedemfobserver.html) | IPMSM扩展反电动势与PLL结构 |
| [MathWorks：Flux Observer](https://www.mathworks.com/help/mcb/ref/fluxobserver.html) | SPMSM磁链基线与偏置/积分处理 |
| [MathWorks：估算器调参](https://www.mathworks.com/help/mcb/gs/tuning-sensorless-position-estimators.html) | SMO/EEMF调参及位置对照 |
| [MathWorks：高频注入观测器](https://www.mathworks.com/help/mcb/ref/pulsatinghighfreqobserver.html) | 低速、初始位置与极性识别 |
| [MathWorks：初始位置示例](https://www.mathworks.com/help/mcb/gs/estimate-initial-rotor-position-using-pulsating-high-frequency-dual-pulse-injection.html) | HFI/双脉冲及相应Plant能力 |
| [MathWorks：EKF](https://www.mathworks.com/help/control/ref/extendedkalmanfilter.html)、[UKF](https://www.mathworks.com/help/control/ref/unscentedkalmanfilter.html) | 通用非线性估计结构；PMSM方程和目标实现另行建立 |
| [TI：Universal Motor Control Lab](https://www.ti.com/lit/ug/spruj26a/spruj26a.pdf) | FAST/eSMO和有位置/无位置方案对照 |

[lib目录](../../model/lib/README.md) · [Sensorless目录](../../model/app_models/Sensorless/README.md) · [总计划](IMPLEMENTATION_PLAN.md)

SL08补齐[四种物理观测FOC](../../model/app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)：每种10项，含正反转、初始角、36V、观测电阻偏差、失锁/旋转复位、正反带速拒绝和观测禁用。复用lib与实际物理桥，20/8/12项跟踪/退出/拒绝分开登记；14M重建、六组日志、真实Scope及推导齐全。SL09代表性MRAS主机结果见[分析](../../model/lib/观测器/模型参考自适应/waveform_analysis/HOST_CODE_ANALYSIS.md)，最终清理见[记录](../validation/cleanup.json)；不执行C2000。

本轮SL01–SL08全部lib及App完成各自MIL、参数、搭建/运行、Scope和波形资料。SL09只完成代表性MRAS状态更新函数主机检查；完整SLX/App single转换与App SIL留作后续，不按已完成登记。
