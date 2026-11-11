# HFI位置启动、低速FOC与HFI/EEMF混合控制

## 用途

包含独立位置启动模型和HFI低速FOC模型：正交凸极资格、实测逆电感均值、轴线跟踪和双脉冲极性完成后，接通电流/速度或直接转矩控制。算法与控制器通过lib库链接共用，真实角度仅用于物理对象及误差评分。新增HFI↔EEMF物理混合模型：两路独立跟踪、双向资格、注入撤除/恢复和π分支重接，继续共用lib。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/SensorlessHFIHybrid.slx](src/SensorlessHFIHybrid.slx) | 已创建 |
| [parameter/HYBRID_PARAMETERS.md](parameter/HYBRID_PARAMETERS.md) | 已创建 |
| [build_process/HYBRID_BUILD.md](build_process/HYBRID_BUILD.md) | 已创建 |
| [build_process/HYBRID_USAGE.md](build_process/HYBRID_USAGE.md) | 已创建 |
| [waveform_analysis/HYBRID_ANALYSIS.md](waveform_analysis/HYBRID_ANALYSIS.md) | 已创建 |
| [src/SensorlessHFIStartup.slx](src/SensorlessHFIStartup.slx) | 已创建 |
| [src/SensorlessHFIFOC.slx](src/SensorlessHFIFOC.slx) | 已创建 |
| [parameter/hfi_foc_app_parameters.m](parameter/hfi_foc_app_parameters.m) | 已创建 |
| [parameter/FOC_PARAMETERS.md](parameter/FOC_PARAMETERS.md) | 已创建 |
| [build_process/FOC_BUILD.md](build_process/FOC_BUILD.md) | 已创建 |
| [build_process/FOC_USAGE.md](build_process/FOC_USAGE.md) | 已创建 |
| [waveform_analysis/FOC_ANALYSIS.md](waveform_analysis/FOC_ANALYSIS.md) | 已创建 |
| [parameter/hfi_startup_app_parameters.m](parameter/hfi_startup_app_parameters.m) | 已创建 |
| [parameter/hfi_startup_test_parameters.m](parameter/hfi_startup_test_parameters.m) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |

[模型](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| 启动命令、负载、ADC及资格故障工况 | 输入 | SI | double兼容 | 50 μs |
| 机械速度/转矩请求及模式 | FOC输入 | rad/s、N·m、0/1 | double | 50 μs刺激表 |
| 完整电角度、资格、极性、阶段及诊断 | 输出 | SI | double兼容 | 50 μs |

自包含物理测试模型使用7列刺激表和6份ToWorkspace日志，9组Scope的实际顺序见[完整接口表](parameter/README.md)。完整位置资格需要极性已识别且连续轴线重新锁定；独立探针或轴线资格均不足以单独放行转矩。

新增FOC模型使用10列刺激表、9份50 μs日志及9组Scope，完整顺序见[FOC参数页](parameter/FOC_PARAMETERS.md)。速度PI实际按1 ms更新；重新接通控制时由共用SpeedProfile清状态并限斜率。

混合模型为11列刺激、12份完整日志和15组Scope；融合角、omega_base及最终valid实际参与控制，真实角仅评分。[混合接口及Scope](parameter/HYBRID_PARAMETERS.md)与原两模型分别登记。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 混合控制、EEMF及Fusion组合 | SI | [hfi_hybrid_app_parameters.m](parameter/hfi_hybrid_app_parameters.m) |
| 混合速度往返、负载及测量工况 | SI | [hfi_hybrid_test_parameters.m](parameter/hfi_hybrid_test_parameters.m) |
| lib与电机组合 | SI | [hfi_startup_app_parameters.m](parameter/hfi_startup_app_parameters.m) |
| 物理工况及测量 | SI | [hfi_startup_test_parameters.m](parameter/hfi_startup_test_parameters.m) |
| FOC控制器、位置链、限值及电机组合 | SI | [hfi_foc_app_parameters.m](parameter/hfi_foc_app_parameters.m) |
| FOC命令、负载、ADC及延迟 | SI | [hfi_foc_test_parameters.m](parameter/hfi_foc_test_parameters.m) |

## 验证

R2026b物理MIL共22项通过，包含正常/π反向、角度、名义平均电感失配、ADC、执行/采样年龄、无饱和/圆转子、不等实际伏秒、运动、禁能/复位和故障。应拒绝识别的反例按拒绝验收，不表示22个可用运行点。

位置启动默认约86.45 ms取得完整资格，两侧峰值约3.7586/2.7480 A，实际伏秒均.004 V·s；该独立模型ADC工况角RMS约.005625 rad。新增FOC完成24项物理MIL，默认8 rad/s负载阶跃末段真实速度误差RMS约.002470 rad/s、电角误差约.019535 rad，未知交叉电感反例仍保留。原两模型合计46项App MIL；新增混合模型18项通过，本模块合计64项App MIL，不重复计为lib测试。原始数据、开发失败/修正对照和正式路径核对见[波形目录](waveform_analysis/README.md)。混合模型的重新搭建及正式路径默认运行均与受测12份日志一致。其高速/低速指观测区域，尚未进入弱磁；带速捕获、single/SIL及C2000验证继续推进。
