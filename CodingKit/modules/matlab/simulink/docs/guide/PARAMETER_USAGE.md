# M文件参数入口

参数的默认值和可配置工况保存在对应模块的`parameter/*.m`；README说明输入、过程、输出、单位和Scope。模型加载回调把配置结构体及默认输入放入模型工作区，仿真时使用这些结构体字段。需要长期修改默认值时编辑M文件，停止仿真后重新执行初始化函数；一次实验使用SimulationInput覆盖，不把实验值写回SLX。

## lib入口

| 模块 | 控制/对象参数 | 默认测试工况入口 | 重新加载 |
|---|---|---|---|
| discrete_pid | [discrete_pid_parameters.m](../../model/lib/离散并联PID/parameter/discrete_pid_parameters.m) | [pid_test_parameters.m](../../model/lib/离散并联PID/parameter/pid_test_parameters.m) | initialize_discrete_pid_test('DiscretePIDTest') |
| math | [clarke_park_parameters.m](../../model/lib/math/parameter/clarke_park_parameters.m) | 同一文件；[blend_test_parameters.m](../../model/lib/math/parameter/blend_test_parameters.m)用于BlendDQ | initialize_clarke_park_test('ClarkeParkTest')；initialize_frame_blend_test('FrameBlendTest') |
| pmsm_plant | [pmsm_parameters.m](../../model/lib/永磁同步电机/parameter/pmsm_parameters.m)；[高频/饱和入口](../../model/lib/永磁同步电机/parameter/pmsm_hf_parameters.m) | [pmsm_test_parameters.m](../../model/lib/永磁同步电机/parameter/pmsm_test_parameters.m)；[高频脉冲工况](../../model/lib/永磁同步电机/parameter/hf_plant_test_parameters.m) | initialize_motor_model('PMSMPlantTest')；initialize_hf_plant_test('PMSMHighFrequencyPlantTest') |
| current_loop | [current_parameters.m](../../model/lib/电流环/parameter/current_parameters.m) | [current_loop_test_parameters.m](../../model/lib/电流环/parameter/current_loop_test_parameters.m)；[frame_pi_test_parameters.m](../../model/lib/电流环/parameter/frame_pi_test_parameters.m) | initialize_motor_model('CurrentLoopTest')；initialize_frame_pi_test('FrameTrackingPITest') |
| inverter | [inverter_parameters.m](../../model/lib/逆变器/parameter/inverter_parameters.m) | [inverter_test_parameters.m](../../model/lib/逆变器/parameter/inverter_test_parameters.m) | initialize_motor_model('InverterTest') |
| timing | [timing_parameters.m](../../model/lib/采样执行时序/parameter/timing_parameters.m) | [timing_test_parameters.m](../../model/lib/采样执行时序/parameter/timing_test_parameters.m) | initialize_motor_model('TimingTest') |
| motion_loop | [motion_parameters.m](../../model/lib/运动环/parameter/motion_parameters.m)；[speed_profile_parameters.m](../../model/lib/运动环/parameter/speed_profile_parameters.m) | [motion_loop_test_parameters.m](../../model/lib/运动环/parameter/motion_loop_test_parameters.m)；[speed_profile_test_parameters.m](../../model/lib/运动环/parameter/speed_profile_test_parameters.m) | initialize_motor_model('MotionLoopTest')；initialize_speed_profile_test('SpeedProfileTest') |
| feedforward | [feedforward_parameters.m](../../model/lib/电压前馈/parameter/feedforward_parameters.m) | [feedforward_test_parameters.m](../../model/lib/电压前馈/parameter/feedforward_test_parameters.m) | initialize_motor_model('FeedforwardTest') |
| deadtime | [deadtime_parameters.m](../../model/lib/死区补偿/parameter/deadtime_parameters.m) | [deadtime_test_parameters.m](../../model/lib/死区补偿/parameter/deadtime_test_parameters.m)；[switching_leg_test_parameters.m](../../model/lib/死区补偿/parameter/switching_leg_test_parameters.m) | initialize_motor_model('DeadtimeTest')或('SwitchingLegTest') |
| mtpa_fw | [mtpa_fw_parameters.m](../../model/lib/MTPA弱磁/parameter/mtpa_fw_parameters.m) | [reference_test_parameters.m](../../model/lib/MTPA弱磁/parameter/reference_test_parameters.m) | initialize_mtpa_fw_model('CurrentReferenceTest') |
| angle_tracking | [angle_tracking_parameters.m](../../model/lib/相位跟踪/parameter/angle_tracking_parameters.m) | [pll_test_parameters.m](../../model/lib/相位跟踪/parameter/pll_test_parameters.m) | initialize_angle_tracking_test('AngleTrackingTest') |
| observer_smo | [smo_parameters.m](../../model/lib/观测器/滑模/parameter/smo_parameters.m) | [smo_test_parameters.m](../../model/lib/观测器/滑模/parameter/smo_test_parameters.m) | initialize_smo_test('SlidingModeObserverTest') |
| observer_smo（sigmoid） | [sigmoid_smo_parameters.m](../../model/lib/观测器/滑模/parameter/sigmoid_smo_parameters.m)、[本地PLL](../../model/lib/观测器/滑模/parameter/sigmoid_smo_pll_parameters.m) | [sigmoid_smo_test_parameters.m](../../model/lib/观测器/滑模/parameter/sigmoid_smo_test_parameters.m) | initialize_sigmoid_smo_test('SigmoidSlidingModeObserverTest') |
| observer_emf | [emf_parameters.m](../../model/lib/观测器/反电势/parameter/emf_parameters.m)，spmsm/ipmsm | [emf_test_parameters.m](../../model/lib/观测器/反电势/parameter/emf_test_parameters.m) | initialize_emf_test('LinearEmfTest')或('EemfObserverTest') |
| observer_hfi | [轴线/双角PLL](../../model/lib/观测器/高频注入/parameter/README.md)、[正交探针](../../model/lib/观测器/高频注入/parameter/hfi_probe_parameters.m)、[双脉冲](../../model/lib/观测器/高频注入/parameter/hfi_polarity_parameters.m) | [hfi_test_parameters.m](../../model/lib/观测器/高频注入/parameter/hfi_test_parameters.m)、[物理电机](../../model/lib/观测器/高频注入/parameter/hfi_plant_parameters.m) | initialize_hfi_test或initialize_hfi_probe_test；极性由HFI App初始化组合 |
| observer_ekf | [ekf_parameters.m](../../model/lib/观测器/扩展卡尔曼/parameter/ekf_parameters.m)、[派生量刷新](../../model/lib/观测器/扩展卡尔曼/parameter/refresh_kalman_parameters.m) | [ekf_test_parameters.m](../../model/lib/观测器/扩展卡尔曼/parameter/ekf_test_parameters.m) | 打开本模块完整src路径，initialize_ekf_test('EkfObserverTest')；[运行与Scope](../../model/lib/观测器/扩展卡尔曼/build_process/USAGE.md)；共用[SPMSM过程](../../model/lib/永磁同步电机/parameter/SENSORLESS_PARAMETERS.md) |
| observer_ukf | [ukf_parameters.m](../../model/lib/观测器/无迹卡尔曼/parameter/ukf_parameters.m)、[派生量刷新](../../model/lib/观测器/无迹卡尔曼/parameter/refresh_ukf_parameters.m) | [ukf_test_parameters.m](../../model/lib/观测器/无迹卡尔曼/parameter/ukf_test_parameters.m) | 打开本模块完整src路径，initialize_ukf_test('UkfObserverTest')；[运行/10组Scope](../../model/lib/观测器/无迹卡尔曼/build_process/USAGE.md)，39项预测向量含27项公共参数，由本地M刷新 |
| observer_mras | [mras_parameters.m](../../model/lib/观测器/模型参考自适应/parameter/mras_parameters.m)、[派生量刷新](../../model/lib/观测器/模型参考自适应/parameter/refresh_mras_parameters.m) | [mras_test_parameters.m](../../model/lib/观测器/模型参考自适应/parameter/mras_test_parameters.m) | 打开本模块完整src路径，initialize_mras_test('MrasObserverTest')；[运行与Scope](../../model/lib/观测器/模型参考自适应/build_process/USAGE.md) |
| observer_flux | [flux_parameters.m](../../model/lib/观测器/磁链/parameter/flux_parameters.m) | [flux_test_parameters.m](../../model/lib/观测器/磁链/parameter/flux_test_parameters.m) | initialize_flux_test('FluxObserverTest') |
| sensorless_startup | [startup_parameters.m](../../model/lib/无感启动/parameter/startup_parameters.m) | [startup_test_parameters.m](../../model/lib/无感启动/parameter/startup_test_parameters.m) | initialize_startup_test('SensorlessStartupTest') |
| sensorless_startup（OpenLoopDrive） | [open_loop_drive_parameters.m](../../model/lib/无感启动/parameter/open_loop_drive_parameters.m) | [open_loop_drive_test_parameters.m](../../model/lib/无感启动/parameter/open_loop_drive_test_parameters.m) | initialize_open_loop_drive_test('OpenLoopDriveTest') |
| sensorless_handover | [handover_parameters.m](../../model/lib/无感切换/parameter/handover_parameters.m)；[hybrid_fusion_parameters.m](../../model/lib/无感切换/parameter/hybrid_fusion_parameters.m) | [handover_test_parameters.m](../../model/lib/无感切换/parameter/handover_test_parameters.m)；[hybrid_fusion_test_parameters.m](../../model/lib/无感切换/parameter/hybrid_fusion_test_parameters.m) | initialize_handover_test('SensorlessHandoverTest')；initialize_hybrid_fusion_test('HybridFusionTest') |

测试参数M文件中的命令值、事件时间、enable/reset、时长、频率和可调求解步长在各自函数中列出。输入波形按固定采样网格生成，FromWorkspace的SampleTime取相同周期。修改采样周期后，还要检查所有控制周期、执行延迟、外环周期及Plant步长是否相容。

## App入口

| App | 本模块参数入口 | 重新加载/运行 |
|---|---|---|
| Sensor/experiment | [experiment_app_parameters.m](../../model/app_models/Sensor/experiment/parameter/experiment_app_parameters.m)组合全部配置；[experiment_parameters.m](../../model/app_models/Sensor/experiment/parameter/experiment_parameters.m)定义工况 | initialize_motor_model('MotorExperiment')；run_motor_case |
| Sensor/mtpa_fw | [mtpa_fw_app_parameters.m](../../model/app_models/Sensor/mtpa_fw/parameter/mtpa_fw_app_parameters.m) | initialize_mtpa_fw_model('MTPAFWMotor')；run_mtpa_fw_case |
| Sensor/observer_compare | [observer_compare_parameters.m](../../model/app_models/Sensor/observer_compare/parameter/observer_compare_parameters.m) | initialize_observer_compare('SensorObserverCompare')；run_observer_compare_case |
| Sensorless/sensorless_foc | [sensorless_foc_parameters.m](../../model/app_models/Sensorless/sensorless_foc/parameter/sensorless_foc_parameters.m) | initialize_sensorless_foc('SensorlessFOC')；run_sensorless_foc_case |
| Sensorless/sensorless_hfi启动 | [hfi_startup_app_parameters.m](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_startup_app_parameters.m)、[测试配置](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_startup_test_parameters.m) | initialize_hfi_startup('SensorlessHFIStartup')；run_hfi_startup_validation |
| Sensorless/sensorless_hfi低速FOC | [hfi_foc_app_parameters.m](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_foc_app_parameters.m)、[测试配置](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_foc_test_parameters.m)；[Scope及25列控制日志](../../model/app_models/Sensorless/sensorless_hfi/parameter/FOC_PARAMETERS.md) | initialize_hfi_foc('SensorlessHFIFOC')；run_hfi_foc_validation |
| Sensorless/sensorless_if | [本地参数和 Scope](../../model/app_models/Sensorless/sensorless_if/parameter/README.md) | initialize_if_app('SensorlessIF')；run_if_app_case |
| Sensorless/sensorless_vf | [本地参数和 Scope](../../model/app_models/Sensorless/sensorless_vf/parameter/README.md) | initialize_vf_app('SensorlessVF')；run_vf_app_case |

混合模型新增[hfi_hybrid_app_parameters.m](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_hybrid_app_parameters.m)及[测试入口](../../model/app_models/Sensorless/sensorless_hfi/parameter/hfi_hybrid_test_parameters.m)；`initialize_hfi_hybrid('SensorlessHFIHybrid')`重新加载，`run_hfi_hybrid_validation`验证；15组Scope和12份日志见[参数页](../../model/app_models/Sensorless/sensorless_hfi/parameter/HYBRID_PARAMETERS.md)。

App入口引用lib默认值，在自己的M文件中组合和覆盖电机、采样、限值和工况。没有另设工程顶层参数目录。

## GUI运行与单次覆盖

```matlab
% 从工程根目录运行一次以建立路径。
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
open_system('CurrentLoopTest');
% 编辑current_parameters.m或current_loop_test_parameters.m后刷新。
initialize_motor_model('CurrentLoopTest');
out=sim('CurrentLoopTest');
```

```matlab
% 一次实验覆盖控制增益，不改磁盘默认值和源SLX。
overrides=struct('currentCfg',struct('Kpd',2.5,'Kpq',2.5));
r=run_motor_case('CurrentLoopTest',overrides,[],0.03);
plot(r.trace.time,squeeze(r.trace.signals.values));
% r.parameters记录本次实际使用的全部参数。
```

```matlab
p=sensorless_foc_parameters();
p.focCfg.SpeedReference=60;
p.inverterCfg.Vdc=36;
r=run_sensorless_foc_case(p);
plot(r.time,r.plant.trace(:,r.plant.columns.speed_true));
```

原始测试输入矩阵列顺序以各模块`parameter/README.md`为准。自定义输入必须覆盖仿真时长、符合端口宽度和采样周期；改Base Workspace中的同名变量不能替代模型工作区。MTPA表、SMO系数和启动/接管拍数等派生值由各模块刷新函数生成，不能只改派生值后认为源参数也已更新。

[工程入口](../../README.md) · [运行入口](../scripts/README.md) · [目录规则](../../rules.md)

带速捕获App新增本模块[参数M](../../model/app_models/Sensorless/sensorless_foc/parameter/flying_foc_parameters.m)、[字段/Scope/日志](../../model/app_models/Sensorless/sensorless_foc/parameter/FLYING_PARAMETERS.md)及[单次覆盖/重载示例](../../model/app_models/Sensorless/sensorless_foc/build_process/FLYING_USAGE.md)。

凸极无位置弱磁App新增本模块[可执行参数](../../model/app_models/Sensorless/sensorless_fw/parameter/sensorless_fw_parameters.m)、[全部配置/输入/状态/日志/29组Scope](../../model/app_models/Sensorless/sensorless_fw/parameter/README.md)与[单次覆盖/GUI重载](../../model/app_models/Sensorless/sensorless_fw/build_process/USAGE.md)。实际母线由fwCfg或第7输入给定，refCfg.CurrentMax为实际分配电流限；共用基线未读取的兼容字段已逐项标明。

MRAS/EKF/UKF/sigmoid物理App新增[本地参数M](../../model/app_models/Sensorless/sensorless_foc/parameter/extension_foc_parameters.m)、[配置/状态/六组日志/Scope](../../model/app_models/Sensorless/sensorless_foc/parameter/EXTENSION_PARAMETERS.md)、[单次覆盖/GUI重载](../../model/app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)。估计模型电阻可与真实电机独立配置；原六列与新增七列工况分开。
