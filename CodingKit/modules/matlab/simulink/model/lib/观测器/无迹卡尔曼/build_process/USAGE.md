# 运行UKF、改参数和观察波形

在R2026b切换到本模块目录后运行：

```matlab
addpath('src','parameter','build_process','waveform_analysis');
initialize_ukf_paths();
open_system(fullfile('src','UkfObserverTest.slx'));
initialize_ukf_test('UkfObserverTest');
out=sim(Simulink.SimulationInput('UkfObserverTest'));
trace=reshape(out.trace.signals.values,50,[]).';
```

也可以打开验证模型后直接点击Run。原始日志为50×1×N；保存的records.trace已统一为N×50，时间在records.time。先看AngleScope、SpeedScope和StatusScope，再看创新、NIS、两组标准差和RateMismatch。Status中计数可到400拍，看标志时可在图例中隐藏计数；每组通道的来源、列号与单位见[参数页](../parameter/README.md)。只打开当前检查的Scope，看完关闭。

## 修改长期默认值

[ukf_parameters.m](../parameter/ukf_parameters.m)组合过程/P0/Q/R/资格与本模块UT参数；[ukf_test_parameters.m](../parameter/ukf_test_parameters.m)组合真实轨迹与评分设置。修改后重新执行initialize_ukf_test。前者的初角/初速是估计先验，后者的InitialAngle/ElectricalSpeed是真实验证输入，两者含义不同。

## 一次实验覆盖

```matlab
p=ukf_parameters();
p.Alpha=.2;
p.MeasurementStd=[.003;.003];
p=refresh_ukf_parameters(p);
in=Simulink.SimulationInput('UkfObserverTest');
in=in.setVariable('ukfCfg',p,'Workspace','UkfObserverTest');
out=sim(in);
```

该覆盖只改变此次运行。刷新函数同时重算公共27项Settings和39项UnscentedSettings、点尺度及权重；不能只改cfg.Alpha而继续用旧打包向量。已有Alpha=.2、Kappa=2的独立工况可比较资格初始段；它们在当前轨迹的稳态差别很小，不据此认为更小Alpha总会更好。

改变采样周期时，同时刷新Q、角变化率低通、资格拍数并重建匹配的testStim时间网格。改变真实电流/速度/噪声时，通过共用spmsm_estimation_fixture重新生成输入；只修改估计Model.Rs不改变真实电机参数，用于失配实验。增大初始θ标准差可能使sigma点超出本模块局部角范围并触发故障3，应根据已有初始角信息设置。

## 批量验证与绘图

```matlab
run_ukf_numerical_validation();  % 21项纯M，公开对象比较需Control System Toolbox
run_ukf_validation();           % 29项独立Simulink输入MIL
run_ukf_validation({'positive','reversal','sigma_alpha_small'});
plot_ukf_results();             % 三组本模块波形
compare_ekf_ukf();               % 与兄弟EKF已保存25项数据核对并导出对照图
```

完整MIL保存results.mat/metrics.json；子集另存subset_results/metrics，不覆盖完整结果。每个记录保存配置、测试输入、truth、评分窗口、50列数据与指标。数值检查另存numerical_results.mat/numerical_metrics.json，参考差异见[说明](../waveform_analysis/REFERENCE_BEHAVIOR.md)。

库模型负责估计与资格，独立验证模型提供运行示例；实际FOC接管、single整模型、SIL和C2000验证分别进行。检查结束关闭本次模型/Scope和图窗，保留MATLAB主窗口；批量脚本不打开编辑器。
