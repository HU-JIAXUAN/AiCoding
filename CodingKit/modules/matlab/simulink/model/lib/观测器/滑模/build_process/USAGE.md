# 运行、调参和观察波形

R2026b 中打开 src/SlidingModeObserverTest.slx，PostLoadFcn 自动载入 smoCfg、pllCfg 和 testStim，直接 Run。先展开 SMO 查看电流预测、注入、滤波和相位处理，再进入链接的 PLL 查看角度跟踪。

批量验证：切到 waveform_analysis，执行 run_smo_validation。它用 SimulationInput 覆盖当次模型工作区，结果保存 MAT/JSON 与 PNG/SVG。

单次修改示例（先打开测试台，并将 parameter 加入 MATLAB 路径）：

~~~matlab
cfg = smo_parameters();
cfg.FilterHz = 800;
cfg = refresh_smo_parameters(cfg);
pll = angle_tracking_parameters();
pll.Ts = cfg.Ts;
pll.MinMagnitude = cfg.MinEmf;
in = Simulink.SimulationInput('SlidingModeObserverTest');
in = in.setVariable('smoCfg',cfg,'Workspace','SlidingModeObserverTest');
in = in.setVariable('pllCfg',pll,'Workspace','SlidingModeObserverTest');
in = in.setModelParameter('StopTime','0.3');
out = sim(in);
plot(out.trace.time,out.trace.signals.values(:,22))
~~~

第 22 列是估算角度减去真实角度的包角误差，单位 rad。改变 Rs/L/Ts/SlidingGain/Boundary/FilterHz 后都调用 refresh_smo_parameters；改变 Ts 时同时更新 PLL、测试输入时间轴与固定步长。电机参数失配实验应分别设置真实对象与观测器参数，不能把二者一起改掉后宣称鲁棒。

本模块默认50µs，现有电流环基线为100µs；接入App前必须对齐采样/作用区间并重新调参。只把默认Ts改为100µs会使当前边界层线性极点越出单位圆，refresh_smo_parameters会拒绝该组合。当前默认PMSM对象的Ld≠Lq，也不能直接当成本版SPMSM验证对象；先覆盖为Ld=Lq工况，或后续使用EEMF。

双击 AngleScope、SpeedScope、EmfScope、CurrentScope、StatusScope。完整顺序和 22 列 trace 见 [参数说明](../parameter/README.md)。增大 SlidingGain 可能使离散边界层不稳定；加大滤波也会增加相移。先看电流预测和 EMF，再调整 PLL。

Scope工具栏的Autoscale用于缩放，Legend显示通道名称。AngleScope的两条角度曲线在±π处都会跳变，应看第三通道包角误差。StatusScope混合方向/0–1状态与相位误差，可用信号选择器单独观察valid；注入z只在trace第17/18列记录，没有送入独立Scope。
