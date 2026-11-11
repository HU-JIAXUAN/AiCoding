# 线性反电势与扩展反电势观测

## 用途

已构建SPMSM线性Luenberger反电势观测器和IPMSM扩展反电势观测器。两者共用电流/反电势四状态方程，SPMSM取Ld=Lq；IPMSM保留转速相关的凸极项。PLL复用angle_tracking，真实角度只送入测试台误差分析。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/EmfObserver.slx](src/EmfObserver.slx) | 已创建 |
| [src/LinearEmfTest.slx](src/LinearEmfTest.slx) | 已创建 |
| [src/EemfObserverTest.slx](src/EemfObserverTest.slx) | 已创建 |
| [src/emf_predict.m](src/emf_predict.m) | 已创建 |
| [parameter/emf_parameters.m](parameter/emf_parameters.m) | 已创建 |
| [parameter/emf_test_parameters.m](parameter/emf_test_parameters.m) | 已创建 |
| [build_process/build_emf_observer.m](build_process/build_emf_observer.m) | 已创建 |
| [waveform_analysis/run_emf_validation.m](waveform_analysis/run_emf_validation.m) | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

两种导出块均为7输入、12输出；每个实例的观测器配置和PLL配置分别通过Mask传入。LinearEMF使用SPMSM参数，要求Ld=Lq。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha / u_beta | 输入 | V | double | 50 μs |
| i_alpha / i_beta | 输入 | A | double | 50 μs |
| direction / enable / reset | 输入 | ±1 / 逻辑 / 逻辑 | double兼容 | 50 μs |
| theta_e_hat / omega_e_hat / valid | 输出 | 电角rad / 电角rad/s / 逻辑 | double | 50 μs |
| emf、i_hat、residual各αβ分量 | 输出 | V / A / A | double | 50 μs |
| phase_measured / emf_magnitude / phase_error | 输出 | rad / V / rad | double | 50 μs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| Ts、Rs、Ld、Lq、BandwidthHz、有效性阈值 | SI | [emf_parameters.m](parameter/emf_parameters.m) |
| Duration、ElectricalSpeed、InitialAngle、Id/Iq及开关 | SI | [emf_test_parameters.m](parameter/emf_test_parameters.m) |

## 验证

两个测试台已在正式路径完成32项独立MIL，包含保持使能的零速/低速；3个源/测试SLX的正式重新加载、源码一致性与默认编译运行检查通过。结果见[metrics.json](waveform_analysis/metrics.json)和[ANALYSIS.md](waveform_analysis/ANALYSIS.md)。未完成本模块的SIL、C2000构建或实机验证。
