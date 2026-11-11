# SPMSM基础与sigmoid滑模观测器

## 用途

用实际作用的 αβ 电压和采样电流估算 SPMSM 反电势，复用 [相位跟踪](../../相位跟踪/README.md) 的 PLL 跟踪转子电角度。基础版为边界层SMO、显式低通与相移补偿；新增按书12.3.3式(12.24)实现的sigmoid版本，采用tanh等价形式，不另设EMF低通。两者限定Ld=Lq，分别维护库和Test，共用PLL；不把本实现称为TI eSMO。R2026b实现。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SlidingModeObserver.slx](src/SlidingModeObserver.slx) | 已创建 |
| [src/SlidingModeObserverTest.slx](src/SlidingModeObserverTest.slx) | 已创建 |
| [src/SigmoidSlidingModeObserver.slx](src/SigmoidSlidingModeObserver.slx) | 已创建 |
| [src/SigmoidSlidingModeObserverTest.slx](src/SigmoidSlidingModeObserverTest.slx) | 已创建 |
| [parameter/SIGMOID_PARAMETERS.md](parameter/SIGMOID_PARAMETERS.md) | 已创建 |
| [build_process/SIGMOID_STEPS.md](build_process/SIGMOID_STEPS.md) | 已创建 |
| [build_process/SIGMOID_USAGE.md](build_process/SIGMOID_USAGE.md) | 已创建 |
| [waveform_analysis/SIGMOID_ANALYSIS.md](waveform_analysis/SIGMOID_ANALYSIS.md) | 已创建 |
| [waveform_analysis/sigmoid_verification.json](waveform_analysis/sigmoid_verification.json) | 已创建 |
| [参数定义](parameter/smo_parameters.m) | 已创建 |
| [派生系数](parameter/refresh_smo_parameters.m) | 已创建 |
| [搭建脚本](build_process/build_sliding_mode_observer.m) | 已创建 |
| [独立验证脚本](waveform_analysis/run_smo_validation.m) | 已创建 |

[搭建过程](build_process/STEPS.md) · [运行与调参](build_process/USAGE.md) · [波形分析](waveform_analysis/ANALYSIS.md)

## 接口

下表为原基础版。sigmoid保持7个在线输入，发布14个输出，具体顺序、4个保持量、24列日志及6组Scope见[SIGMOID_PARAMETERS](parameter/SIGMOID_PARAMETERS.md)。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha / u_beta | 输入 | V，相电压峰值约定 | double | smoCfg.Ts |
| i_alpha / i_beta | 输入 | A | double | smoCfg.Ts |
| direction | 输入 | -1 / 0 / +1 | double | smoCfg.Ts |
| enable / reset | 输入 | 0/1 | double | smoCfg.Ts |
| theta_e_hat / phase_measured / phase_error | 输出 | 电角 rad | double | smoCfg.Ts |
| omega_e_hat | 输出 | 电角 rad/s | double | smoCfg.Ts |
| valid | 输出 | 0/1 | double | smoCfg.Ts |
| emf_alpha / emf_beta / injection_alpha / injection_beta / emf_magnitude | 输出 | V | double | smoCfg.Ts |
| i_hat_alpha / i_hat_beta | 输出 | A | double | smoCfg.Ts |

direction 必须来自已知启动方向/经验证的方向管理，0 表示方向不可用；本版不自动识别风车方向。输入不包含真实角度/速度。机械速度 = omega_e_hat/PolePairs。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| smoCfg：Ts、Rs、L、SlidingGain、Boundary、FilterHz、MinEmf、MinOmega、Compensate | s、Ω、H、V、A、Hz、rad/s | [smo_parameters.m](parameter/smo_parameters.m) |
| smoCfg.A/B/FilterA/BoundaryPole | 1、A/V | [refresh_smo_parameters.m](parameter/refresh_smo_parameters.m) |
| pllCfg | 见 PLL 模块 | [angle_tracking_parameters.m](../../相位跟踪/parameter/angle_tracking_parameters.m) |
| sigmoidCfg及派生值 | 逐字段SI | [sigmoid_smo_parameters.m](parameter/sigmoid_smo_parameters.m)、[refresh](parameter/refresh_sigmoid_smo_parameters.m) |
| sigmoid版本pllCfg | SI及资格拍数 | [sigmoid_smo_pll_parameters.m](parameter/sigmoid_smo_pll_parameters.m) |
| sigmoid工况与阈值 | SI | [sigmoid_smo_test_parameters.m](parameter/sigmoid_smo_test_parameters.m) |

详见 [参数/Scope 通道](parameter/README.md)。Flux/PolePairs 用于测试与量纲转换，不进入基础电流观测更新。参数是合成 MIL 工况，不是实际电机标定结果。

基础版继续使用原smoCfg/pllCfg接口。sigmoid版本通过cfg/trackerCfg两个Mask分别绑定不同结构体，并用双实例与各自单独运行逐点对照验证配置和状态隔离；修改默认值在本地M入口完成。

## 验证

入口：[run_smo_validation.m](waveform_analysis/run_smo_validation.m)。结果：`results.mat`（运行验证后生成）、[metrics.json](waveform_analysis/metrics.json)。

基础版原14项独立MIL及旧两份SLX保留；其[Sensor并行对照](../../../app_models/Sensor/observer_compare/README.md)和[SensorlessFOC](../../../app_models/Sensorless/sensorless_foc/README.md)已有各自整机结果。新增sigmoid完成22项独立MIL：11个正常跟踪、10个拒绝/故障、1个10mA噪声资格限制诊断；另有10项纯M、实例隔离及6次匹配对照。源码独立重建与正式路径默认24列差值0，参数、实际库链接和6组Scope已核对。

[运行与调参](build_process/SIGMOID_USAGE.md) · [波形与限制](waveform_analysis/SIGMOID_ANALYSIS.md)。10mA噪声下资格覆盖约0.8991，原0.95标准未放宽，原始失败保留；22项通过不代表22个可用工况。sigmoid另已完成[物理App10项接管/拒绝/退出](../../../app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)；single核冒烟不等于完整single/SIL，C2000暂缓、实机另验。
