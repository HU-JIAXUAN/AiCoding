# 运行与调参

使用R2026b，在本模块build_process执行：

```matlab
open_system('../src/SensorlessStartupTest.slx')
```

点击Run。加载回调创建startupCfg及testStim到模型工作区；默认输入为enable=1、reset=0、direction=1、acquired=0，完整演示直到超时。AngleScope为软件电角度，SpeedScope为软件角速度，CurrentScope为虚拟d/q电流请求；StatusScope和ElapsedScope的通道见[参数页](../parameter/README.md)。Scope中可用Autoscale缩放时间与幅值。

单次修改配置和输入：

```matlab
cfg=startup_parameters();
cfg.FinalOmega=300;
cfg=refresh_startup_parameters(cfg);
sample=(0:round(1.1/cfg.Ts))';
t=sample*cfg.Ts;
stim.time=t;
stim.signals.values=[ones(size(t)),zeros(size(t)),-ones(size(t)),double(sample>=round(0.6/cfg.Ts))];
stim.signals.dimensions=4;
in=Simulink.SimulationInput('SensorlessStartupTest');
in=in.setVariable('startupCfg',cfg,'Workspace','SensorlessStartupTest');
in=in.setVariable('testStim',stim,'Workspace','SensorlessStartupTest');
out=sim(in);
plot(out.trace.time,out.trace.signals.values(:,[6,7]))
```

第6列单位rad/s，第7列单位A；正式分析请分轴显示。以上覆盖只作用于本次仿真，重新打开模型恢复默认值；在已打开模型中可调用initialize_startup_test('SensorlessStartupTest')恢复。输入时间范围须覆盖StopTime，四列顺序为enable、reset、direction、acquired。批量检查进入waveform_analysis运行run_startup_validation。

展开库内部查看Unit Delay和SequenceStep；在MATLAB Function编辑器修改代码后同步src/startup_step.m并重新验证。正常使用不用重建；需要复现搭建时，在独立模块副本中移除源SLX后运行build_sensorless_startup，原目录脚本会拒绝覆盖已有模型。
