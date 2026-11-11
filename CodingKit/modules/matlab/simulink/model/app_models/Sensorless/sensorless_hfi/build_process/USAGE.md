# 运行、修改参数和看波形

在MATLAB R2026b中，将当前目录切到本模块，然后执行：

```matlab
addpath('build_process','parameter','waveform_analysis');
open_system(fullfile('src','SensorlessHFIStartup.slx'));
initialize_hfi_startup('SensorlessHFIStartup');
out=sim(Simulink.SimulationInput('SensorlessHFIStartup'));
```

只打开当前模型及正在看的Scope，用完保存并关闭。后台批量验证用`run_hfi_startup_validation`，脚本不打开编辑器，结束后关闭本测试模型。

本模块入口[hfi_startup_app_parameters.m](../parameter/hfi_startup_app_parameters.m)组合库配置；[hfi_startup_test_parameters.m](../parameter/hfi_startup_test_parameters.m)定义时长、初始位置、ADC和延迟。永久修改默认值后再次`initialize_hfi_startup`；函数更新模型工作区，不清空MATLAB基础工作区。库配置修改基础字段后调用相应`refresh_*`，重建派生向量。

单次实验可覆盖工作区变量而不修改SLX，例如：

```matlab
cfg=hfi_startup_app_parameters();
cfg.Test.CurrentResolution=16/4096;
cfg.Test.MeasurementNoise=.001;
in=Simulink.SimulationInput('SensorlessHFIStartup');
in=in.setVariable('hfiStartupTestCfg',cfg.Test,'Workspace','SensorlessHFIStartup');
in=in.setVariable('testStim',hfi_startup_stimulus(cfg.Test),'Workspace','SensorlessHFIStartup');
out=sim(in);
```

初始角度、速度或电机饱和特性同时影响`hfPlantCfg`，不能只改测试结构体而保留旧电机状态。重建默认组合最直接；临时工况按[验证脚本](../waveform_analysis/run_hfi_startup_validation.m)设置`Motor.Position0`、`Motor.Speed0`并refresh。修改`Ts`必须同步HFI/PLL/Probe/Polarity、刺激表和PlantStep。

先看`StageScope`与`ValidityScope`，确认探针完成、脉冲阶段、极性形成和重新锁定；然后看`PeakScope`与`DoseScope`，确认判据成立的原因；最后用`AngleScope`、`SpeedScope`和`ADCScope`检查误差、运动及测量干扰。所有通道及六份日志列顺序见[参数README](../parameter/README.md)。
