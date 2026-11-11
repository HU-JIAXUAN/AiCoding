# 运行、调参及查看带速捕获波形

先运行工程`docs/scripts/initialize_motor_paths.m`注册共享lib和App路径，再执行：

```matlab
load_system('FlyingFluxFOC');
p = flying_foc_parameters();
[out,p] = run_flying_foc_case(p);
t = out.plant_trace.time;
plot(t,out.plant_trace.signals.values(:,11)); % 实际机械速度，rad/s
```

`run_flying_foc_case`采用SimulationInput，只覆盖这次运行的模型工作区。若要在Simulink里看模型，`open_system('FlyingFluxFOC')`后点Run；先只开根层的SpeedScope与ModeScope，接管后再看Controller中的CurrentScope与VoltageScope。看完关闭Scope和模型，不同时打开所有App。

修改默认值时编辑本模块[参数M](../parameter/flying_foc_parameters.m)，执行`initialize_flying_foc('FlyingFluxFOC')`重新载入，再点Run。命令行做单次试验时修改返回的`p`即可：

```matlab
p = flying_foc_parameters();
p.bridgeCfg.Speed0 = -80;                 % 物理初值
p.experimentCfg.SpeedReference = -100;    % 命令，无需另给观测器方向
[out,p] = run_flying_foc_case(p);

p = flying_foc_parameters();
p.bridgeCfg.Vdc = 36;
p.flyingCfg.CaptureVoltageMax = 0.9*36/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.experimentCfg.SpeedReference = 90;
[out,p] = run_flying_foc_case(p);
```

准备看故障关断时，设置`p.experimentCfg.ObserverOffTime=0.6`；保持ObserverOnTime为inf。查看ModeScope中的桥模式0，再看OffCurrentScope中的续流，不把电压指令0误读成高阻。

```matlab
report = run_flying_foc_validation(); % 13项物理MIL，含明确拒绝
logic = run_flying_logic_checks();   % 8组准备阶段/复位/跟踪代数检查
plot_flying_foc_results();           % 从保存MAT导出三组PNG/SVG，无图窗残留
close_system('FlyingFluxFOC',0);
```

验证脚本在本模块`waveform_analysis/`保存`flying_*.mat`和结果JSON。每份MAT含实际参数p、Plant/Observer/Controller日志、工况预期和指标。日志列号及Scope通道见[参数页](../parameter/FLYING_PARAMETERS.md)。

再次运行完整验证会更新这组结果；改算法源码时应先复制模块M到隔离目录，用[构建器](build_flying_foc.m)生成新的SLX并验证，不能把编辑M当成已经更新SLX内嵌算法。
