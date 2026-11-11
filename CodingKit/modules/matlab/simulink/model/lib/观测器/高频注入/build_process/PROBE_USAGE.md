# 运行正交凸极探针

在R2026b中切到observer_hfi模块目录：

```matlab
addpath('build_process');
open_system(fullfile(pwd,'src','HFISaliencyTest.slx'));
initialize_hfi_probe_test('HFISaliencyTest');
out = sim('HFISaliencyTest');
y = out.trace.signals.values;
plot(out.trace.time,y(:,[13,14,15]));
legend('Saliency ratio','Qualified','Done');
```

模型PostLoadFcn执行同一初始化，参数进入模型工作区，点击Run即可运行。默认0.05 s、ode4/2.5 μs，采样50 μs；探针在14.4 ms停止请求并保持结果，物理电机继续积分。

长期修改默认值时编辑本模块[hfi_probe_parameters.m](../parameter/hfi_probe_parameters.m)和[hfi_probe_test_parameters.m](../parameter/hfi_probe_test_parameters.m)，再重新初始化。一次实验使用SimulationInput：

```matlab
addpath('parameter');
p = hfi_probe_parameters();
p.CaptureSamples = 512;
p = refresh_hfi_probe_parameters(p);
input = Simulink.SimulationInput('HFISaliencyTest');
input = input.setVariable('probeCfg',p,'Workspace','HFISaliencyTest');
out = sim(input);
```

改变Ts还需同步测试参数Ts、PlantStep以及重新生成hfi_stimulus。改变初始角、饱和或交叉电感时重新构造hfPlantCfg；不要只改配置结构体而遗漏派生Settings/InitialState。若延长采集超过测试Duration，需要同时延长测试时长。

先看ProbeStatusScope的qualified、done、fault_code和quality_code；done=1不等于通过。再看ProbeTensorScope的张量和特征值、ProbeFitScope的凸极比/残差、ProbeAngleScope的π等价误差。移动轴时，完成后的theta_axis保持而真实角继续变化，这是快照语义。全部通道顺序和38列日志见[参数页](../parameter/PROBE_PARAMETERS.md#scope-通道)。

完整独立测试及绘图：

```matlab
addpath('waveform_analysis');
report = run_hfi_probe_validation();
plot_hfi_probe_results();
```

脚本保存每个工况的实际输入、参数和波形，反例按“应拒绝资格”验收。该探针保持独立lib接口；平均逆电感现已在[HFI App](../../../../app_models/Sensorless/sensorless_hfi/README.md)接入连续HFI并串接极性与低速FOC。qualified仍不能直接用作完整位置有效标志。
