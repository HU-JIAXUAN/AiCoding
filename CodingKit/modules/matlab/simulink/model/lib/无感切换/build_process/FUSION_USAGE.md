# 运行融合测试、修改参数和观察切换

在R2026b中将当前目录切到本模块。交互查看时只打开当前模型：

```matlab
addpath('src','parameter','build_process','waveform_analysis');
open_system(fullfile('src','HybridFusionTest.slx'));
initialize_hybrid_fusion_test('HybridFusionTest');
out=sim(Simulink.SimulationInput('HybridFusionTest'));
```

默认两路是解析位置估计，不是实际PMSM响应。先看WeightScope：速度升高后基波权重由0到1，注入比例在更高速度撤到0；降速提前恢复注入，确认分支后权重返回0。低速候选在.85 s额外跳π，最终融合角应保持连续。

再看AngleErrorScope和StatusScope，区分候选位置、最终控制角、来源valid、连续合格及最终valid。SpeedScope的omega_frame含相位修正，不能把它当作电机真实加减速。CountScope检查资格首次连续累计和2 ms预测窗口。完整顺序、来源、单位和27列记录见[参数页](../parameter/FUSION_PARAMETERS.md)。

永久修改入口为[hybrid_fusion_parameters.m](../parameter/hybrid_fusion_parameters.m)和[hybrid_fusion_test_parameters.m](../parameter/hybrid_fusion_test_parameters.m)，然后重新初始化。单次覆盖示例：

```matlab
cfg=hybrid_fusion_parameters();
cfg.BlendTime=.08;
cfg=refresh_hybrid_fusion_parameters(cfg);
test=hybrid_fusion_test_parameters();
test.InitialOmega=-20;test.PeakOmega=-100;
in=Simulink.SimulationInput('HybridFusionTest');
in=in.setVariable('fusionCfg',cfg,'Workspace','HybridFusionTest');
in=in.setVariable('fusionTestCfg',test,'Workspace','HybridFusionTest');
in=in.setVariable('testStim',hybrid_fusion_stimulus(test,cfg),'Workspace','HybridFusionTest');
out=sim(in);
angle=out.trace.signals.values(:,11);
```

改Ts后必须重新refresh并重新生成刺激表；固定步长引用fusionCfg.Ts，不另在SLX里存默认数值。实例Mask引用配置结构体，调用模型工作区保存本次参数。

批量入口为`report=run_hybrid_fusion_validation()`，选单项可传`{'round_trip'}`等名称。脚本后台加载、结束后关闭测试台；数据和指标写本模块waveform_analysis。绘图入口`plot_hybrid_fusion_results()`只创建不可见图并在导出后关闭。交互检查结束关闭Scope及模型，保留MATLAB主窗口。
