# 四状态SPMSM估计过程与独立输入

本页说明EKF/后续UKF共用的过程M函数；它没有新增SLX或Scope。[pmsm_sensorless_parameters.m](pmsm_sensorless_parameters.m)调用原pmsm_parameters，取Ld作为SPMSM单L；原PMSMPlant的Lq=1.2 mH及原IPMSM测试参数仍按原定义使用。

## 配置参数

| 名称 | 默认值 | 单位 | 用途 |
|---|---:|---|---|
| Ts | 50e−6 | s | 离散过程周期 |
| Rs | 0.5 | Ω | 每相电阻 |
| L | 0.001 | H | SPMSM单轴电感，取原Ld |
| Flux | 0.035 | Wb | 永磁磁链 |
| PolePairs | 4 | 1 | 电/机械速度换算，不进入四状态过程方程 |

参数入口与过程函数分离；修改后重新生成各观测器cfg并刷新其派生量。观测器P0/Q/R和资格由各自parameter维护，不属于本过程函数的电机参数。

## 输入信号

[pmsm_sensorless_step.m](../src/pmsm_sensorless_step.m)输入x(4)、u(2)、p(4)。x依次为iα/A、iβ/A、ωe/(电角rad/s)、θe/电角rad；u为实际作用uα/uβ，单位V；p依次为Ts、Rs、L、Flux。当前电压用于[kTs,(k+1)Ts)的下一拍预测。

[pmsm_sensorless_measurement.m](../src/pmsm_sensorless_measurement.m)只输入x；返回前两个电流状态和常量H。在线不读取真实转子位置或速度。

## 过程变量与输出信号

```text
iα_next = iα + Ts/L·(uα − Rs·iα + ωe·Flux·sinθe)
iβ_next = iβ + Ts/L·(uβ − Rs·iβ − ωe·Flux·cosθe)
ωe_next = ωe
θe_next = atan2(sin(θe+Ts·ωe), cos(θe+Ts·ωe))
```

函数没有内部保持状态、噪声发生器或复位状态。x_next由调用者保存；第二输出A是4×4解析过程Jacobian。测量输出h=[iα;iβ]，H=[1 0 0 0;0 1 0 0]。A/H无量纲项与各状态单位有关，不能将全部元素解释成同一物理单位。离散过程近似每个采样区间恒速；加速度不作为第五状态。

## 独立输入与Scope

[spmsm_estimation_fixture.m](../build_process/spmsm_estimation_fixture.m)按独立连续dq电压平衡生成轨迹，不调用离散过程或Jacobian。输入为等间隔time、ωe、初始θe、id、iq、电机参数和方向先验；积分ω得到角度，电流导数由gradient得到。输出stimulus的9列依次为uα/V、uβ/V、iα/A、iβ/A、direction/−1或0或+1、enable/0或1、reset/0或1、真实θe/rad、真实ωe/rad/s。truth另外保存展开角、dq电流、实际电压与电机参数。

本过程M没有Scope。原PMSMPlantTest和高频对象的Scope分别保留在[本目录README](README.md)和[HF_PARAMETERS.md](HF_PARAMETERS.md)；EKF的10组Scope和50列日志在[observer_ekf参数页](../../观测器/扩展卡尔曼/parameter/README.md)登记。真实θ/ω只供测试台对照，不能接回在线估计器。

## 运行与范围

将本模块src、parameter、build_process、waveform_analysis添加MATLAB路径后，调用pmsm_sensorless_parameters、pmsm_sensorless_step或run_sensorless_process_validation。数值核对见[过程检查记录](../waveform_analysis/SENSORLESS_PROCESS.md)。完整估计器运行见[EKF教程](../../观测器/扩展卡尔曼/build_process/USAGE.md)。本过程未提供机械起转、凸极高频响应或IPMSM扩展方程；相应对象继续使用本模块原有SLX。
