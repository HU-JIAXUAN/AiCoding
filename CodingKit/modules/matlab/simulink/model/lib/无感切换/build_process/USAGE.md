# 运行、调参和观察

在R2026b切到本模块build_process：

```matlab
open_system('../src/SensorlessHandoverTest.slx')
```

点击Run。加载回调把handoverCfg和testStim放入模型工作区。默认软件角度比估算角度领先0.4 rad，两者均为200电角rad/s，valid在0.02 s置1；0.03 s开始混合，0.13005 s进入AUTO。六组Scope和22列trace的顺序见[参数页](../parameter/README.md)。

每个Handover库块的Handover configuration填写配置结构表达式，默认handoverCfg。单次覆盖示例：

```matlab
cfg=handover_parameters();
cfg.BlendTime=0.15;
cfg=refresh_handover_parameters(cfg);
in=Simulink.SimulationInput('SensorlessHandoverTest');
in=in.setVariable('handoverCfg',cfg,'Workspace','SensorlessHandoverTest');
out=sim(in);
plot(out.trace.time,out.trace.signals.values(:,15)) % beta
```

在waveform_analysis运行run_handover_validation执行全部19项；也可运行run_handover_validation({'long_dropout','phase_jump'})只检查选中工况。结果报告中的tests/passed和cases实际对应本次选择；最后一次完整验证保存19项。SimulationInput不覆盖SLX默认值；initialize_handover_test('SensorlessHandoverTest')可恢复已打开模型的默认参数和输入。

修改testStim时，11列依次为theta_start、omega_start、ready、startup_mode、startup_fault、theta_hat、omega_hat、observer_valid、residual_norm、enable、reset。用整数采样点生成事件，例如sample>=round(0.2/cfg.Ts)，时间为sample*cfg.Ts；验证脚本逐点核对记录的输入与请求输入，避免浮点时间比较造成事件偏移。

AngleScope观察启动/估算/控制角和初始偏移；SpeedScope分开看基准速度与含过渡修正的规划速度。BlendScope看beta，StatusScope看资格及运行状态，CountScope看持续计数，ResidualScope看A单位残差。状态码最大5，Scope自动纵轴可能压低0/1标志，可用信号选择器单独查看run/fault。

重建只在独立模块副本执行build_sensorless_handover，原目录拒绝覆盖SLX。修改handover_step.m后须同步SequenceStep函数块并重新验证；正常Run不需要重建。
