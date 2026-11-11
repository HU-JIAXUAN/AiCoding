# 运行HFI闭环、改参数和读取数据

在MATLAB R2026b将当前目录切到本模块，然后执行：

```matlab
addpath('build_process','parameter','waveform_analysis');
open_system(fullfile('src','SensorlessHFIFOC.slx'));
initialize_hfi_foc('SensorlessHFIFOC');
out=sim(Simulink.SimulationInput('SensorlessHFIFOC'));
```

默认初始电角.7 rad，位置启动后接通电流环；.14 s起速度给定爬升至8机械rad/s，.7 s加入.02 N·m负载。仿真1.2 s，控制/观测50 μs、速度PI 1 ms、ode4步长2.5 μs。

永久改默认值，编辑[hfi_foc_test_parameters.m](../parameter/hfi_foc_test_parameters.m)及[hfi_foc_app_parameters.m](../parameter/hfi_foc_app_parameters.m)，随后重新初始化。测试入口定义命令/噪声/延迟，App入口组合库参数与限值；不在SLX块里维护另一份默认数值。

一次试验使用SimulationInput。例如只改变速度请求和负载：

```matlab
p=hfi_foc_app_parameters();
p.Test.SpeedReference=-8;
p.Test.LoadTorque=-.02;
in=Simulink.SimulationInput('SensorlessHFIFOC');
in=in.setVariable('hfiFocTestCfg',p.Test,'Workspace','SensorlessHFIFOC');
in=in.setVariable('testStim',hfi_foc_stimulus(p.Test),'Workspace','SensorlessHFIFOC');
out=sim(in);
```

改变电机或初始位置时同步更新hfPlantCfg/pmsmCfg；改变周期时同步HFI、PLL、Probe、Polarity、Current、Profile、刺激表及步长。完整覆盖例子见[run_hfi_foc_validation.m](../waveform_analysis/run_hfi_foc_validation.m)。

先看ValidityScope，区分完整位置有效、控制接通、App锁存故障和极性故障；再看SpeedScope、TorqueScope、CurrentScope；最后用VoltageScope和IntegralScope检查限压/回算。电流中包含HFI纹波，不能把50 μs原始电流与1 ms均值混为同一指标。所有真实通道及日志列见[参数页](../parameter/FOC_PARAMETERS.md)。

批量运行`report=run_hfi_foc_validation()`，脚本后台加载并在结束后关闭该模型；波形和参数快照写入本模块waveform_analysis。绘图运行`plot_hfi_foc_results()`，图窗不显示、导出后关闭。交互检查只打开当前模型/Scope，用完关闭，保留MATLAB主窗口。
