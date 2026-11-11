# 受保护模型发布接口

本工程的 25 份库 SLX 已覆盖，共 42 份可引用的 `.slxp`。每份文件固定本次发布的参数、采样和数据类型。`SLX` 源库及 Test 供工程内部维护，`SLXP` 可单独交给接收方。当前发布配置为 **R2026b Update 1、Windows x64、Simulation**，使用 MinGW64 仿真目标，未启用只读模型视图。目标代码发布按芯片和工具链另建配置。

## 接收和接入

1. 将所需 SLXP 的文件夹加入 MATLAB 路径。在上层模型中放置 Model block，选择该 SLXP。可用 `Simulink.ProtectedModel.createHarness("文件名.slxp")` 生成独立接收台。
2. 按 [发布契约 JSON](../validation/protected_model_contracts.json) 接线。每条记录包括源库块、端口顺序、名称、数据类型、维度、采样、参数快照、重放工况和 SHA-256。信号物理单位及配置含义见对应模块的 parameter README。
3. 按接收端工况验证。需要改增益、采样周期、对象参数或运行模式时，以新配置重建和重放。包的 SHA-256 用于核对接收文件；接口变更由契约记录和重放检查发现。

## 模型清单

| 库接口 | 受保护模型 | 入 / 出 | 重放样本最大绝对差 |
| --- | --- | ---: | ---: |
| `AngleTracking/PLL` | [AngleTrackingProtected.slxp](../../model/lib/相位跟踪/src/AngleTrackingProtected.slxp) | 4 / 6 | 0 |
| `ClarkePark/BlendDQ` | [ClarkePark_BlendDQProtected.slxp](../../model/lib/math/src/ClarkePark_BlendDQProtected.slxp) | 7 / 1 | 0 |
| `ClarkePark/Clarke` | [ClarkePark_ClarkeProtected.slxp](../../model/lib/math/src/ClarkePark_ClarkeProtected.slxp) | 3 / 3 | 0 |
| `ClarkePark/InverseClarke` | [ClarkePark_InverseClarkeProtected.slxp](../../model/lib/math/src/ClarkePark_InverseClarkeProtected.slxp) | 3 / 3 | 0 |
| `ClarkePark/InversePark` | [ClarkePark_InverseParkProtected.slxp](../../model/lib/math/src/ClarkePark_InverseParkProtected.slxp) | 3 / 2 | 0 |
| `ClarkePark/Park` | [ClarkePark_ParkProtected.slxp](../../model/lib/math/src/ClarkePark_ParkProtected.slxp) | 3 / 2 | 0 |
| `ControlTiming/Actuation` | [ControlTiming_ActuationProtected.slxp](../../model/lib/采样执行时序/src/ControlTiming_ActuationProtected.slxp) | 1 / 2 | 0 |
| `ControlTiming/Feedback` | [ControlTiming_FeedbackProtected.slxp](../../model/lib/采样执行时序/src/ControlTiming_FeedbackProtected.slxp) | 1 / 2 | 0 |
| `CurrentControl/FrameTrackingPI` | [CurrentControl_FrameTrackingPIProtected.slxp](../../model/lib/电流环/src/CurrentControl_FrameTrackingPIProtected.slxp) | 7 / 3 | 0 |
| `CurrentControl/TrackingPI` | [CurrentControl_TrackingPIProtected.slxp](../../model/lib/电流环/src/CurrentControl_TrackingPIProtected.slxp) | 4 / 2 | 0 |
| `CurrentControl/VoltageLimit` | [CurrentControl_VoltageLimitProtected.slxp](../../model/lib/电流环/src/CurrentControl_VoltageLimitProtected.slxp) | 1 / 2 | 0 |
| `CurrentReference/Allocator` | [CurrentReference_AllocatorProtected.slxp](../../model/lib/MTPA弱磁/src/CurrentReference_AllocatorProtected.slxp) | 6 / 19 | 0 |
| `CurrentReference/TorquePI` | [CurrentReference_TorquePIProtected.slxp](../../model/lib/MTPA弱磁/src/CurrentReference_TorquePIProtected.slxp) | 4 / 2 | 5.08e-13 |
| `DQFeedforward/Feedforward` | [DQFeedforwardProtected.slxp](../../model/lib/电压前馈/src/DQFeedforwardProtected.slxp) | 3 / 2 | 0 |
| `Deadtime/Compensation` | [Deadtime_CompensationProtected.slxp](../../model/lib/死区补偿/src/Deadtime_CompensationProtected.slxp) | 3 / 3 | 0 |
| `Deadtime/SwitchingLeg` | [Deadtime_SwitchingLegProtected.slxp](../../model/lib/死区补偿/src/Deadtime_SwitchingLegProtected.slxp) | 2 / 3 | 0 |
| `Deadtime/VoltageError` | [Deadtime_VoltageErrorProtected.slxp](../../model/lib/死区补偿/src/Deadtime_VoltageErrorProtected.slxp) | 3 / 3 | 0 |
| `DiscretePID/Controller` | [DiscretePIDProtected.slxp](../../model/lib/离散并联PID/src/DiscretePIDProtected.slxp) | 3 / 5 | 0 |
| `EkfObserver/EKF` | [EkfObserver_EKFProtected.slxp](../../model/lib/观测器/扩展卡尔曼/src/EkfObserver_EKFProtected.slxp) | 7 / 25 | 0 |
| `EmfObserver/EEMF` | [EmfObserver_EEMFProtected.slxp](../../model/lib/观测器/反电势/src/EmfObserver_EEMFProtected.slxp) | 7 / 12 | 0 |
| `EmfObserver/LinearEMF` | [EmfObserver_LinearEMFProtected.slxp](../../model/lib/观测器/反电势/src/EmfObserver_LinearEMFProtected.slxp) | 7 / 12 | 0 |
| `FluxObserver/Flux` | [FluxObserverProtected.slxp](../../model/lib/观测器/磁链/src/FluxObserverProtected.slxp) | 6 / 14 | 0 |
| `HighFrequencyObserver/HFIAxis` | [HighFrequencyObserver_HFIAxisProtected.slxp](../../model/lib/观测器/高频注入/src/HighFrequencyObserver_HFIAxisProtected.slxp) | 8 / 15 | 0 |
| `HighFrequencyObserver/SaliencyProbe` | [HighFrequencyObserver_SaliencyProbeProtected.slxp](../../model/lib/观测器/高频注入/src/HighFrequencyObserver_SaliencyProbeProtected.slxp) | 6 / 16 | 5.68e-13 |
| `Inverter/Average` | [Inverter_AverageProtected.slxp](../../model/lib/逆变器/src/Inverter_AverageProtected.slxp) | 3 / 3 | 0 |
| `Inverter/SVPWM` | [Inverter_SVPWMProtected.slxp](../../model/lib/逆变器/src/Inverter_SVPWMProtected.slxp) | 2 / 4 | 0 |
| `MotionControl/Position` | [MotionControl_PositionProtected.slxp](../../model/lib/运动环/src/MotionControl_PositionProtected.slxp) | 3 / 1 | 0 |
| `MotionControl/Speed` | [MotionControl_SpeedProtected.slxp](../../model/lib/运动环/src/MotionControl_SpeedProtected.slxp) | 4 / 3 | 0 |
| `MotionControl/SpeedProfile` | [MotionControl_SpeedProfileProtected.slxp](../../model/lib/运动环/src/MotionControl_SpeedProfileProtected.slxp) | 3 / 2 | 0 |
| `MrasObserver/CurrentModelMRAS` | [MrasObserverProtected.slxp](../../model/lib/观测器/模型参考自适应/src/MrasObserverProtected.slxp) | 7 / 16 | 0 |
| `OpenLoopDrive/Reference` | [OpenLoopDriveProtected.slxp](../../model/lib/无感启动/src/OpenLoopDriveProtected.slxp) | 6 / 8 | 0 |
| `PMSMBridgeBusPlant/BridgeBusMotor` | [PMSMBridgeBusPlantProtected.slxp](../../model/lib/永磁同步电机/src/PMSMBridgeBusPlantProtected.slxp) | 4 / 16 | 0 |
| `PMSMBridgePlant/BridgeMotor` | [PMSMBridgePlantProtected.slxp](../../model/lib/永磁同步电机/src/PMSMBridgePlantProtected.slxp) | 3 / 16 | 0 |
| `PMSMHighFrequencyPlant/HFPMSM` | [PMSMHighFrequencyPlantProtected.slxp](../../model/lib/永磁同步电机/src/PMSMHighFrequencyPlantProtected.slxp) | 3 / 10 | 0 |
| `PMSMPlant/Electrical` | [PMSMPlant_ElectricalProtected.slxp](../../model/lib/永磁同步电机/src/PMSMPlant_ElectricalProtected.slxp) | 3 / 3 | 0 |
| `PMSMPlant/Mechanical` | [PMSMPlant_MechanicalProtected.slxp](../../model/lib/永磁同步电机/src/PMSMPlant_MechanicalProtected.slxp) | 2 / 4 | 0 |
| `SensorlessHandover/Handover` | [SensorlessHandover_HandoverProtected.slxp](../../model/lib/无感切换/src/SensorlessHandover_HandoverProtected.slxp) | 11 / 11 | 0 |
| `SensorlessHandover/HybridFusion` | [SensorlessHandover_HybridFusionProtected.slxp](../../model/lib/无感切换/src/SensorlessHandover_HybridFusionProtected.slxp) | 8 / 17 | 0 |
| `SensorlessStartup/Startup` | [SensorlessStartupProtected.slxp](../../model/lib/无感启动/src/SensorlessStartupProtected.slxp) | 4 / 8 | 0 |
| `SigmoidSlidingModeObserver/SigmoidSMO` | [SigmoidSlidingModeObserverProtected.slxp](../../model/lib/观测器/滑模/src/SigmoidSlidingModeObserverProtected.slxp) | 7 / 14 | 0 |
| `SlidingModeObserver/SMO` | [SlidingModeObserverProtected.slxp](../../model/lib/观测器/滑模/src/SlidingModeObserverProtected.slxp) | 7 / 12 | 0 |
| `UkfObserver/UKF` | [UkfObserverProtected.slxp](../../model/lib/观测器/无迹卡尔曼/src/UkfObserverProtected.slxp) | 7 / 25 | 0 |

以下子系统暂随源库或上层组合维护，没有单独的受保护发布入口。

- `CurrentReference/CurrentLimits`
- `CurrentReference/FieldWeakening`
- `CurrentReference/MTPA`
- `EkfObserver/KalmanMeasurement`
- `HighFrequencyObserver/PolarityPulse`

三个电流给定辅助块和卡尔曼校正辅助块未登记独立测试装配。HFI 极性双脉冲继续由现有 App 验证，现有组合测试台的模型引用转换未通过。

## 重新生成

在工程根目录的 MATLAB 会话中运行下列命令。建议使用新的临时目录，避免和已发布包同名。

```matlab
addpath(fullfile(pwd,'docs','scripts'))
delivery = rebuild_protected_models(string(tempname));
% 单独更新离散并联 PID 时可选择库块：
% delivery = rebuild_protected_models(string(tempname),"DiscretePID/Controller");
```

默认重建已登记的发布接口。新增发布接口时，给第二个参数传入 `Library/Block` 并提供能调用该库块的测试台。生成结果留在临时工作区的 `delivery`。审查通过的端口和参数报告，再把对应 SLXP 更新到库模块 src。选用非默认测试配置时一并记录其参数和工况。

[维护计划](../plans/PROTECTED_MODEL_PLAN.md) · [MathWorks 接收受保护模型](https://www.mathworks.com/help/simulink/ug/use-a-protected-model-in-simulation.html)
