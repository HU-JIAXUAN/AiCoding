# 切换参数、状态和Scope

新增HybridFusion使用独立的[hybrid_fusion_parameters.m](hybrid_fusion_parameters.m)和[hybrid_fusion_test_parameters.m](hybrid_fusion_test_parameters.m)，初始化为`initialize_hybrid_fusion_test('HybridFusionTest')`；8输入、20状态、17输出及六组Scope见[FUSION_PARAMETERS.md](FUSION_PARAMETERS.md)。原单向Handover参数/Scope继续如下维护。

## 配置参数

默认工况的可执行入口为[handover_test_parameters.m](handover_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_handover_test('SensorlessHandoverTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

定义：[handover_parameters.m](handover_parameters.m)；派生计数由[refresh_handover_parameters.m](refresh_handover_parameters.m)刷新。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e-6 | s | 离散更新周期 |
| MinOmega | 100 | 电角rad/s | 普通有效速度下限，正反向取绝对值 |
| MaxSpeedGap | 80 | 电角rad/s | 普通捕获的软件/估算速度差上限 |
| MaxPhaseGap | 0.9 | 电角rad | 普通捕获的包角相位差上限 |
| MaxResidual | 1.5 | A | 观测器电流残差范数上限 |
| CaptureTime / BlendTime / LossTime | 0.01 / 0.1 / 0.001 | s | 捕获连续时长、合格样本混合时长、失效连续时长 |
| MaxPhaseInnovation | 0.15 | 电角rad | 当前观测相位相对上一安全状态预测的包角偏差上限 |
| AllowFlying | 1 | 0/1 | 启用startup_mode=1的零电流捕获条件 |
| Samples | [200;2000;20] | 采样点 | max(1,round([CaptureTime;BlendTime;LossTime]/Ts)) |
| Vector | 10×1 | 各字段单位 | Ts、MinOmega、MaxSpeedGap、MaxPhaseGap、MaxResidual、Samples三项、MaxPhaseInnovation、AllowFlying |
| State0 | zeros(9,1) | 混合状态 | Unit Delay初值 |

库Mask的Handover configuration接受逐实例配置表达式。默认值属于当前仿真夹具，不能作为所有电机和估计器的通用门限。

## 输入信号

| 名称 | 单位 | 类型/默认 | 来源和用途 |
|---|---|---|---|
| theta_start / omega_start | 电角rad / rad/s | double | 软件启动场角及速度 |
| ready | 0/1 | double / 1 | 启动器允许普通捕获检查 |
| startup_mode | 状态码 | double / 4 | Startup的模式；仅1表示零电流窗口 |
| startup_fault | 原因码 | double / 0 | 接管前上游启动故障 |
| theta_hat / omega_hat | 电角rad / rad/s | double | 同时刻观测相位和速度，非Plant真值 |
| observer_valid | 0/1 | double / 0后置1 | 观测器本身的有效标志 |
| residual_norm | A | double / 0.1 | 观测电流与测量电流差的二维范数；不同估计器由调用方对齐定义 |
| enable / reset | 0/1 | double / 1、0 | 总使能、优先复位 |

本模型约定输入角度包到[-π,π]且所有输入有限。端口与testStim前11列顺序一致：theta_start、omega_start、ready、startup_mode、startup_fault、theta_hat、omega_hat、observer_valid、residual_norm、enable、reset。startup_mode=1时调用方保证零电流请求，并已正确处理观测角方向/极性；本模块不会推断SMO方向或HFI极性。

## 过程变量

| 名称 | 单位/初值 | 所在块 | 用途 |
|---|---|---|---|
| state(1) mode | 状态码 / 0 | state Unit Delay | 0关闭、1启动、2资格累计、3混合、4AUTO、5故障 |
| state(2) qualificationN | 采样点 / 0 | 同上 | 连续合格计数，失败归零，捕获后保持 |
| state(3) blendN | 采样点 / 0 | 同上 | 只在健康样本增加，范围0到BlendSamples |
| state(4) lossN | 采样点 / 0 | 同上 | 连续失效计数，健康归零，故障时保持 |
| state(5) offset | rad / 0 | 同上 | 首拍混合的wrap(theta_start-theta_hat_safe) |
| state(6) lastTheta | rad / 0 | 同上 | 最后控制角，故障时保持 |
| state(7) fault | 原因码 / 0 | 同上 | 1启动失败、2估算持续失效、3非法内部模式 |
| state(8) safeHat | rad / 0 | 同上 | 混合前跟随输入，混合/闭环时仅接收合格观测或短时预测 |
| state(9) safeOmega | rad/s / 0 | 同上 | 短时失效的角度预测速度 |
| beta | 1 / 0 | SequenceStep | r²(3-2r)，r=blendN/BlendSamples |
| phase innovation | rad | SequenceStep局部变量 | wrap(theta_hat-(safeHat_prev+Ts*safeOmega_prev))；没有单独送入Scope |

## 输出信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| theta_used | 电角rad | double / theta_start | 输出1；最终采用的控制角，故障保持最后值 |
| omega_base | 电角rad/s | double / 0 | 输出2；启动时为软件速度，混合/闭环为安全观测速度 |
| omega_frame | 电角rad/s | double / 0 | 输出3；下一步坐标规划速度，包含beta变化修正，非机械速度 |
| beta | 1 | double / 0 | 输出4；角度与物理电流参考的过渡权重 |
| mode / fault | 状态/原因码 | double / 0 | 输出5/6；首个故障锁存，复位或禁能清除 |
| acquired | 0/1 | double / 0 | 输出7；只有mode=4为1，延迟一拍送Startup |
| run | 0/1 | double / 0 | 输出8；允许上层控制链运行，非硬件保护结果 |
| qualification_count / loss_count | 采样点 | double / 0 | 输出9/10；当前拍状态计数 |
| phase_offset | 电角rad | double / 0 | 输出11；保存的过渡角差 |

对外角度是本拍值；omega_frame描述理想预测下到下一拍的规划值。新观测的相位修正可能使实际角度增量与规划值略有差异。beta到1后再过一拍进入AUTO。失效计数达到20后下一状态为故障，测试中的0.2 s失效在0.201 s退出。

## Scope 通道

六组Scope均为一个向量端口，以下顺序已与实际连接核对。trace是前11列输入加后11列输出。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1 | theta_start | inputs输出1；trace1 | rad / double | 软件启动场角 |
| AngleScope 2 | theta_hat | inputs输出6；trace6 | rad / double | 原始观测相位与突跳 |
| AngleScope 3 | theta_used | Handover输出1；trace12 | rad / double | 实际选择及过渡角 |
| AngleScope 4 | phase_offset | Handover输出11；trace22 | rad / double | 冻结的包角偏移 |
| SpeedScope 1 | omega_start | inputs输出2；trace2 | rad/s / double | 软件场速度 |
| SpeedScope 2 | omega_hat | inputs输出7；trace7 | rad/s / double | 输入观测速度 |
| SpeedScope 3 | omega_base | Handover输出2；trace13 | rad/s / double | 过渡的基础转动速度 |
| SpeedScope 4 | omega_frame | Handover输出3；trace14 | rad/s / double | 含坐标过渡的规划速度 |
| BlendScope 1 | beta | Handover输出4；trace15 | 1 / double | 平滑权重及暂停 |
| StatusScope 1 | ready | inputs输出3；trace3 | 0/1 / double | 普通捕获允许 |
| StatusScope 2 | observer_valid | inputs输出8；trace8 | 0/1 / double | 观测器标志 |
| StatusScope 3 | mode | Handover输出5；trace16 | 状态码 / double | 捕获/混合/AUTO/故障 |
| StatusScope 4 | fault | Handover输出6；trace17 | 原因码 / double | 锁存退出原因 |
| StatusScope 5 | acquired | Handover输出7；trace18 | 0/1 / double | 完全接管 |
| StatusScope 6 | run | Handover输出8；trace19 | 0/1 / double | 上层控制使能 |
| CountScope 1 | qualification_count | Handover输出9；trace20 | 采样点 / double | 连续资格计数 |
| CountScope 2 | loss_count | Handover输出10；trace21 | 采样点 / double | 短时失效与退出计数 |
| ResidualScope 1 | residual_norm | inputs输出9；trace9 | A / double | 输入电流残差 |

startup_mode、startup_fault、enable、reset只进入trace4、5、10、11，没有送入Scope。相位创新也未单独送入Scope，可从相位输入和上一安全状态分析；不能将valid=1单独当作最终运行资格。

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |

### 本模块局部量

$\theta_{ctrl}$是输出控制坐标角，$\theta_{target}$是融合目标角，均为本模块局部量；原表$\theta_r$只指真实电转子位置。$\hat\theta_r,\hat\omega_r$表示估计量，两源下标L/H、safe、pred分别标明来源与保持/外推。
