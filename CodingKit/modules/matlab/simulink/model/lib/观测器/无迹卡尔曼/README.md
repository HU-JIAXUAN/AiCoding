# 四状态SPMSM无迹卡尔曼观测器

## 用途

与EKF共用[iα,iβ,ωe,θe]过程、电流测量和Joseph校正库链接，通过9个sigma点传播下一拍状态及协方差。角度使用圆周均值/包角残差；有界协方差修复和角分布范围单独记录。独立库与验证模型已完成；[物理App接管10项](../../../app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)已另行验证；完整single/SIL继续，C2000暂缓。

## 文件

| 路径 | 状态 |
|---|---|
| [src/UkfObserver.slx](src/UkfObserver.slx) | 已创建 |
| [src/UkfObserverTest.slx](src/UkfObserverTest.slx) | 已创建 |
| [src/ukf_predict.m](src/ukf_predict.m) | 已创建 |
| [parameter/ukf_parameters.m](parameter/ukf_parameters.m) | 已创建 |
| [parameter/refresh_ukf_parameters.m](parameter/refresh_ukf_parameters.m) | 已创建 |
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |

[源码](src/README.md) · [参数](parameter/README.md) · [过程](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md) · [原理与公式](docs/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha/u_beta | 输入 | V | double | cfg.Model.Ts |
| i_alpha/i_beta | 输入 | A | double | cfg.Model.Ts |
| direction/enable/reset | 输入 | −1/0/+1、0/1 | double兼容 | cfg.Model.Ts |
| theta/omega/valid | 输出 | 电角rad、rad/s、0/1 | double | cfg.Model.Ts |
| 电流、创新、P/K、资格及修复计数 | 输出 | 见参数说明 | double | cfg.Model.Ts |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 物理模型、P0/Q/R、资格 | SI | [ukf_parameters.m](parameter/ukf_parameters.m)组合EKF入口 |
| Alpha/Beta/Kappa、数值尺度与修复范围 | 1及状态单位 | [ukf_parameters.m](parameter/ukf_parameters.m) |
| 输入及评分 | SI | [ukf_test_parameters.m](parameter/ukf_test_parameters.m) |

## 验证

R2026b下29/29项独立轨迹MIL、21项纯M数值检查及不同参数并行实例检查通过。与EKF的25个共同工况输入、公共P0/Q/R和参数逐项相同；数据对照与计算量记录单独保存，不以主机耗时代表C2000时序。M源重新搭建与正式目录默认50列/时间完全一致，内嵌预测与共享校正库链接核对通过，4组波形图已查看。

[运行](build_process/USAGE.md) · [搭建](build_process/STEPS.md) · [波形分析](waveform_analysis/ANALYSIS.md) · [结果](waveform_analysis/metrics.json) · [证据](waveform_analysis/verification.json)。算法来源与物理过程分别登记，不将UKF算法归给主要书籍。
