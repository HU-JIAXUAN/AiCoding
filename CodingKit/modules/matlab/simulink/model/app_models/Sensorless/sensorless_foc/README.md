# 无位置传感器 FOC

## 用途

SPMSM无位置速度闭环，提供SMO、EEMF、磁链三份启动App及一份带速捕获App。前三份共用Plant、Measurement、Controller和VoltageStage，只在Observer内部接入不同lib和诊断。Controller使用测量电流、估算角度/速度及工况命令；真实角度只用于电机物理坐标换算和离线分析。

新增MRAS、EKF、UKF、sigmoid四份桥耦合物理App，共同SPMSM、实际端电压/电流和低端电压启动互锁；每份20个lib链接。离线选择明确模型，未实现运行中任意换算法。[搭建](build_process/EXTENSION_BUILD.md)、[运行](build_process/EXTENSION_USAGE.md)、[参数/Scope](parameter/EXTENSION_PARAMETERS.md)、[40项分析](waveform_analysis/EXTENSION_ANALYSIS.md)。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md)、[docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SensorlessFOC.slx](src/SensorlessFOC.slx) | 已创建 |
| [src/EemfSensorlessFOC.slx](src/EemfSensorlessFOC.slx) | 已创建 |
| [src/FluxSensorlessFOC.slx](src/FluxSensorlessFOC.slx) | 已创建 |
| [src/FlyingFluxFOC.slx](src/FlyingFluxFOC.slx)、[parameter/flying_foc_parameters.m](parameter/flying_foc_parameters.m) | 已创建 |
| [build_process/FLYING_BUILD.md](build_process/FLYING_BUILD.md)、[build_process/FLYING_USAGE.md](build_process/FLYING_USAGE.md)、[parameter/FLYING_PARAMETERS.md](parameter/FLYING_PARAMETERS.md) | 已创建 |
| [waveform_analysis/FLYING_ANALYSIS.md](waveform_analysis/FLYING_ANALYSIS.md)、[waveform_analysis/flying_verification.json](waveform_analysis/flying_verification.json) | 已创建 |
| [parameter/sensorless_foc_parameters.m](parameter/sensorless_foc_parameters.m)、[parameter/observer_foc_parameters.m](parameter/observer_foc_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md)、[parameter/OBSERVER_PARAMETERS.md](parameter/OBSERVER_PARAMETERS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md)、[build_process/OBSERVER_USAGE.md](build_process/OBSERVER_USAGE.md) | 已创建 |
| [build_process/OBSERVER_STEPS.md](build_process/OBSERVER_STEPS.md)、[build_process/build_observer_foc.m](build_process/build_observer_foc.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md)、[waveform_analysis/OBSERVER_ANALYSIS.md](waveform_analysis/OBSERVER_ANALYSIS.md) | 已创建 |
| [waveform_analysis/observer_foc_verification.json](waveform_analysis/observer_foc_verification.json) | 已创建 |
| [src/MrasSensorlessFOC.slx](src/MrasSensorlessFOC.slx) | 已创建 |
| [src/EkfSensorlessFOC.slx](src/EkfSensorlessFOC.slx) | 已创建 |
| [src/UkfSensorlessFOC.slx](src/UkfSensorlessFOC.slx) | 已创建 |
| [src/SigmoidSensorlessFOC.slx](src/SigmoidSensorlessFOC.slx) | 已创建 |
| [parameter/extension_foc_parameters.m](parameter/extension_foc_parameters.m)、[parameter/EXTENSION_PARAMETERS.md](parameter/EXTENSION_PARAMETERS.md) | 已创建 |
| [build_process/EXTENSION_BUILD.md](build_process/EXTENSION_BUILD.md)、[build_process/EXTENSION_USAGE.md](build_process/EXTENSION_USAGE.md) | 已创建 |
| [waveform_analysis/EXTENSION_ANALYSIS.md](waveform_analysis/EXTENSION_ANALYSIS.md) | 已创建 |

[模型](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| testStim六列工况 | 输入 | 机械rad/s、N·m、逻辑、方向 | Structure With Time，double，六列 | 50μs |
| 三相电流 / 最终作用相电压 | 内部物理与采样 | A / V | double向量3 | 对象5μs；采样50μs |
| Observer θ̂ / ω̂ / valid / 残差 | 内部反馈 | 电角rad / 电角rad/s / 1 / A或A-equivalent | double标量 | 50μs |
| Controller电压请求 / 控制角 | 内部输出 | V / 电角rad | double向量2 / 标量 | 50μs |
| 三份启动App的四组日志 | 输出 | 按列SI | Structure With Time；Plant13列、Controller46列、Actuation26列；SMO/EEMF Observer20列、Flux22列 | 50μs |
| FlyingFluxFOC工况 / 三组日志 | 输入 / 输出 | 逐列SI | 五列命令；Plant34列、Observer19列、Controller29列 | 物理5μs，控制/日志50μs |
| 四扩展App的testStim七列 | 输入 | 逐列SI/标志 | Structure With Time，double七列 | 50μs |
| 四扩展App的Plant日志 | 输出 | 逐列SI/状态 | Structure With Time，double36列 | 5μs |
| 四扩展App的其他五组日志 | 输出 | 逐列SI/状态 | Observer25/49/49/23列，其余46/25/27/9列 | 50μs |

新增四App使用七列testStim：速度/负载/总使能/复位/方向/观测使能/实际母线。根图无外部Inport/Outport；物理日志36列@5μs，其余Controller46/Allocation25/Actuation27/Guard9列@50μs，Observer为MRAS25、EKF/UKF49、sigmoid23列@50μs；接口/状态在[扩展参数页](parameter/EXTENSION_PARAMETERS.md)。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| pmsmCfg / currentCfg / refCfg / startupCfg / handoverCfg等共同配置 | 逐字段SI | [sensorless_foc_parameters.m](parameter/sensorless_foc_parameters.m) |
| emfCfg / fluxCfg及PLL、接管适配配置 | 逐字段SI或A-equivalent | [observer_foc_parameters.m](parameter/observer_foc_parameters.m) |
| FlyingFluxFOC的bridgeCfg / currentCfg / flyingCfg / fluxCfg等 | 逐字段SI | [flying_foc_parameters.m](parameter/flying_foc_parameters.m) |
| 四扩展App的observerCfg及共同物理/控制配置 | 逐字段SI/计数 | [extension_foc_parameters.m](parameter/extension_foc_parameters.m) |

四种扩展App使用[extension_foc_parameters.m](parameter/extension_foc_parameters.m)和[refresh_extension_foc_parameters.m](parameter/refresh_extension_foc_parameters.m)，本地组合观测、物理桥与共同环路；观测电阻可与真实电机独立覆盖。

修改本模块`parameter/*.m`的默认配置，或向运行器传入`p`作单次覆盖。EEMF使用`emfCfg`、Flux使用`fluxCfg`；PLL幅值阈值和接管残差按观测器物理含义配置。详见[参数入口](parameter/README.md)和[运行示例](build_process/OBSERVER_USAGE.md)。

## 验证

SMO原8项保留；EEMF与Flux各新增8项，共24项物理PMSM MIL。每组包含6项正常闭环、一次失锁退出和一次预期启动失败。两份新模型从当前M源独立重建的默认四组日志与已验证结果完全一致，正式路径核对见[校验记录](waveform_analysis/observer_foc_verification.json)。

新增FlyingFluxFOC直接链接桥耦合对象与磁链观测器，13项物理MIL和8组纯M通过：关断观察→持续资格→PI反电势跟踪准备→同向PWM接管；支持正反转、旋转中复位/禁能再捕获及失锁关断。静止、反向目标和电压余量不足明确拒绝。七组Scope、三组34/19/29列日志、搭建/运行和推导见[带速捕获分析](waveform_analysis/FLYING_ANALYSIS.md)。

三份原启动App仍是双精度SPMSM平均逆变器MIL，飞行捕获关闭；凸极无位置[MTPA/弱磁已在兄弟模块完成16项检查](../sensorless_fw/README.md)。硬件电压重建、主机数值/SIL及C2000/实机结果分别登记，本轮不执行C2000。

三份原启动App的失锁场景仅验证控制请求退出：其0V平均执行模型不是高阻关断，故障后仍出现约15.89A制动电流峰值。这些旧App的关断限制仍保留，见[原波形分析](waveform_analysis/OBSERVER_ANALYSIS.md)；新增FlyingFluxFOC另用桥耦合对象验证关断二极管通路，见[带速分析](waveform_analysis/FLYING_ANALYSIS.md)。

新增四物理App40项组合MIL通过：20跟踪、8退出、12明确拒绝；真实电流矢量最大约3.089A，Scope30/32/32/30，每模型20个库链接。14M独立重建和布局前后默认六组数据逐点差0。正式路径重放四模型六组日志逐点差0，见[校验记录](waveform_analysis/extension_verification.json)；不重复计入lib独立301项。
