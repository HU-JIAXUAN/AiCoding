# 运行EKF、改协方差和看Scope

从本模块目录在R2026b运行：

```matlab
addpath('src','parameter','build_process','waveform_analysis');
initialize_ekf_paths();
open_system(fullfile('src','EkfObserverTest.slx'));
initialize_ekf_test('EkfObserverTest');
out=sim(Simulink.SimulationInput('EkfObserverTest'));
trace=reshape(out.trace.signals.values,50,[]).';
```

包含16元素协方差的原始日志为50×1×N，最后一维是时间。验证脚本将其统一保存为N×50；实际通道、列号和单位见[参数页](../parameter/README.md)。先看AngleScope、SpeedScope和StatusScope，再看InnovationScope、NisScope、两组Sigma及RateMismatch。看完关闭当前Scope。

永久修改本模块[ekf_parameters.m](../parameter/ekf_parameters.m)或[ekf_test_parameters.m](../parameter/ekf_test_parameters.m)，然后重新初始化。Model结构体中的Ts/Rs/L/Flux是过程参数；InitialStd控制P0，ProcessNoiseDensity控制每步Q，MeasurementStd控制R。修改派生字段来源后调用refresh_kalman_parameters，不在SLX逐块固定数值。

一次修改估算电阻或测量噪声假设：

```matlab
p=ekf_parameters();
p.Model.Rs=.6;                  % 输入的真实电机保持原值
p.MeasurementStd=[.003;.003];   % 每次采样的A RMS假设
p=refresh_kalman_parameters(p);
in=Simulink.SimulationInput('EkfObserverTest');
in=in.setVariable('ekfCfg',p,'Workspace','EkfObserverTest');
out=sim(in);
```

改变真实输入、方向、时长或噪声，用测试M入口及共用spmsm_estimation_fixture重新生成testStim。改周期时同时生成匹配时间网格，并刷新Q、角差分滤波和资格拍数；25 μs工况已有独立覆盖。

`run_ekf_validation()`运行25项并保存results.mat/metrics.json；选择工况如`run_ekf_validation({'positive','reversal','zero_speed'})`另存subset_results/metrics。保存每项完整参数、真实对象、输入、评分窗口、50列波形及原始形状；逐拍校验完整协方差。`run_kalman_qualification_check()`验证相反速度分支的资格反例，属于合成状态检查。

零速、未知/错误方向和磁链低估10%的案例按拒绝资格验收；不把它们解释为可用运行点。所有估算器在线都只读u/i和控制命令；真实θ/ω留在测试台评分。当前独立轨迹未包含机械起转、限压、电流控制接管或硬件采样。

检查结束保存需要的修改并关闭模型/Scope，保留MATLAB主窗口。
