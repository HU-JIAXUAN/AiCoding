# 运行、修改参数和观察波形

## 打开与运行

从simulink工程根目录运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
open_system('FluxObserverTest');
out=sim('FluxObserverTest');
t=out.trace.time;
y=out.trace.signals.values;
plot(t,y(:,24)); grid on; ylabel('electrical angle error rad');
```

模型使用固定步长纯离散求解器，默认步长50 μs、时长1 s。也可点击Simulink的Run，双击AngleScope、SpeedScope等查看。Scope不决定算法参数，参数入口及各通道含义见[parameter/README.md](../parameter/README.md)。

## 修改默认值

编辑[flux_parameters.m](../parameter/flux_parameters.m)修改电阻、电感、磁链、滤波与质量门限；编辑[flux_test_parameters.m](../parameter/flux_test_parameters.m)修改速度、电流、初始角、开关及时长。停止仿真后重新加载：

```matlab
initialize_flux_test('FluxObserverTest');
out=sim('FluxObserverTest');
```

初始化会重新生成独立轨迹，并把fluxCfg、pllCfg、fluxTestCfg、testStim放入模型工作区。更改采样周期时要同时更新PLL和输入轨迹，优先通过上述入口重新初始化；不要只改模型FixedStep。

## 单次实验覆盖

```matlab
% 测试泄漏截止频率变化；不修改源SLX或默认M文件。
cfg=flux_parameters();
cfg.LeakHz=20;
cfg=refresh_flux_parameters(cfg);
tracker=angle_tracking_parameters();
tracker.Ts=cfg.Ts; tracker.MinMagnitude=cfg.MinFlux;
input=Simulink.SimulationInput('FluxObserverTest');
input=input.setVariable('fluxCfg',cfg,'Workspace','FluxObserverTest');
input=input.setVariable('pllCfg',tracker,'Workspace','FluxObserverTest');
out=sim(input);
plot(out.trace.time,out.trace.signals.values(:,[12,21,23]));
legend('valid','flux residual A-equivalent','compensation ready'); grid on;
```

该示例只改滤波、不改周期和电机对象。测试实际电机参数不匹配时，应分别配置观测器参数和fixture的实际电机参数；直接修改两者同一个默认值不是参数鲁棒性验证。[run_flux_validation.m](../waveform_analysis/run_flux_validation.m)的resistance_error工况展示这一区别。

## 跑全部验证

```matlab
addpath(fullfile(pwd,'model','lib','观测器','磁链','waveform_analysis'));
report=run_flux_validation();
```

脚本运行24项检查，覆盖健康跟踪、偏置、开关、有效性和有意关闭处理环节的反例。重跑会更新本模块waveform_analysis中的results.mat、metrics.json及PNG/SVG；失败时另外保存failure.mat。反例通过表示观察到预期缺陷或拒绝资格，不表示该配置可用于闭环。

## 读取已有结果

```matlab
folder=fullfile(pwd,'model','lib','观测器','磁链','waveform_analysis');
data=load(fullfile(folder,'results.mat'));
r=data.records.voltage_bias_no_washout;
plot(r.time,r.trace(:,24)); grid on;
disp(r.metric);
```

每个record保存实际观测器/PLL/fixture参数、输入、真实评估量、trace及指标。统一指标窗口为0.8–1.0 s，完整暂态仍在数据中。生产库不接真实角度/速度；当前结果属于独立积木MIL，尚未替换到SensorlessFOC或完成SIL/C2000验证。

[模块入口](../README.md)
