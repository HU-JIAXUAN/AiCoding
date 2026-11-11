# 四状态SPMSM扩展卡尔曼观测器

## 用途

按主要书籍12.4.3估计[iα,iβ,ωe,θe]。电流测量校正与下一拍预测分开，过程/测量模型由pmsm_plant共用。独立导出的KalmanMeasurement用于后续UKF共用线性电流测量校正；UKF仍使用独立的sigma点过程预测。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/EkfObserver.slx](src/EkfObserver.slx) | 已创建 |
| [src/EkfObserverTest.slx](src/EkfObserverTest.slx) | 已创建 |
| [src/kalman_current_update.m](src/kalman_current_update.m) | 已创建 |
| [src/ekf_predict.m](src/ekf_predict.m) | 已创建 |
| [parameter/ekf_parameters.m](parameter/ekf_parameters.m) | 已创建 |

[模型](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha/u_beta | 输入 | V | double | cfg.Model.Ts |
| i_alpha/i_beta | 输入 | A | double | cfg.Model.Ts |
| direction/enable/reset | 输入 | −1/0/+1、0/1 | double兼容 | cfg.Model.Ts |
| theta/omega/valid | 输出 | 电角rad、rad/s、0/1 | double | cfg.Model.Ts |
| 其余状态、创新、协方差与资格诊断 | 输出 | 见参数说明 | double | cfg.Model.Ts |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 过程、P0/Q/R、资格与限值 | SI | [ekf_parameters.m](parameter/ekf_parameters.m) |
| 轨迹、噪声、数据年龄及评分 | SI | [ekf_test_parameters.m](parameter/ekf_test_parameters.m) |

## 验证

R2026b下[run_ekf_validation.m](waveform_analysis/run_ekf_validation.m)完成25/25项独立MIL，逐拍核对完整协方差；另有2项合成资格反例及不同参数并行实例检查。M源重建与正式目录默认50列和时间均完全一致，内嵌源码一致，结束时模型/图窗为0。

[运行与调参](build_process/USAGE.md) · [搭建步骤](build_process/STEPS.md) · [波形分析](waveform_analysis/ANALYSIS.md) · [指标](waveform_analysis/metrics.json) · [验证证据](waveform_analysis/verification.json)。独立输入没有机械/控制闭环；另有[物理App10项检查](../../../app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)完成接管/拒绝/退出；single/SIL和实机结果另记，C2000暂缓。
