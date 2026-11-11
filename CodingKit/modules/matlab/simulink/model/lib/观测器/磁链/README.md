# SPMSM磁链观测器

## 用途

已实现带泄漏积分、直流偏置去除和频率补偿的SPMSM磁链观测器。生产算法只使用αβ电压、电流、使能与复位；PLL复用angle_tracking。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/FluxObserver.slx](src/FluxObserver.slx) | 已创建 |
| [src/FluxObserverTest.slx](src/FluxObserverTest.slx) | 已创建 |
| [src/flux_predict.m](src/flux_predict.m) | 已创建 |
| [src/flux_compute.m](src/flux_compute.m) | 已创建 |
| [parameter/flux_parameters.m](parameter/flux_parameters.m) | 已创建 |
| [parameter/flux_test_parameters.m](parameter/flux_test_parameters.m) | 已创建 |
| [build_process/build_flux_observer.m](build_process/build_flux_observer.m) | 已创建 |
| [waveform_analysis/run_flux_validation.m](waveform_analysis/run_flux_validation.m) | 已创建 |

[src](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

以下为已保存SLX接口，详细端口和过程变量见[参数页](parameter/README.md)。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha / u_beta | 输入 | V | double | 50 μs |
| i_alpha / i_beta | 输入 | A | double | 50 μs |
| enable / reset | 输入 | 逻辑 | double兼容 | 50 μs |
| theta_e_hat / omega_e_hat / valid | 输出 | 电角rad / rad/s / 逻辑 | double | 50 μs |
| 磁链、转矩、相位及资格诊断 | 输出 | Wb、N·m、rad、A等 | double | 50 μs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 电机、周期、滤波和资格限值 | SI | [flux_parameters.m](parameter/flux_parameters.m) |
| 默认轨迹和开关 | SI | [flux_test_parameters.m](parameter/flux_test_parameters.m) |

## 验证

[独立验证脚本](waveform_analysis/run_flux_validation.m)已完成24项MIL，含未知积分初值、直流偏置和不补偿相位的反例；[指标](waveform_analysis/metrics.json)、`results.mat`（运行验证后生成）与[分析](waveform_analysis/ANALYSIS.md)已保存。两个SLX迁入src后，正式路径默认运行与内嵌源码核对通过。尚未完成App替换、single/SIL或目标验证。
