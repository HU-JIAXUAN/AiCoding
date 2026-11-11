# 运行、调参和观察波形

在 R2026b 的 Current Folder 切到本模块 build_process，执行：

~~~matlab
open_system('../src/AngleTrackingTest.slx')
~~~

首次可直接用 Simulink 的 Run。PostLoadFcn 自动加入本模块路径并安装默认 pllCfg、testStim 到模型工作区；重新打开会恢复默认值。若要在已打开模型中恢复默认参数，执行initialize_angle_tracking_test('AngleTrackingTest')。

批量验证：切到 waveform_analysis，执行 run_angle_tracking_validation。脚本用 SimulationInput 覆盖本次输入/参数，不把工况修改写回 SLX。

单次调参示例（先打开测试台）：

~~~matlab
cfg = angle_tracking_parameters();
cfg.Kp = 400;
in = Simulink.SimulationInput('AngleTrackingTest');
in = in.setVariable('pllCfg',cfg,'Workspace','AngleTrackingTest');
in = in.setModelParameter('StopTime','0.3');
out = sim(in);
plot(out.trace.time,out.trace.signals.values(:,[6 8]))
~~~

图中第 6 列为真实电角速度，第 8 列为 PLL 速度。输入 testStim 的列顺序为 phase、magnitude、enable、reset、theta_true、omega_true；最后两列只进测试记录和 Scope，不进入库算法。

双击 AngleScope、SpeedScope、StatusScope 观察波形，各通道顺序见 [参数说明](../parameter/README.md)。断点、单步运行和展开 PLL 均可用于观察状态；不要为调参断开测试台中的库链接。

需要不同参数的多个PLL时，双击各库块，在PLL configuration中分别填写模型工作区变量名，如pllA和pllB。变量内容必须包含angle_tracking_parameters返回的完整字段，Ts保持各自调用周期一致。默认表达式pllCfg继续兼容原测试台和SMO。

打开../src/AngleTrackingInstancesTest.slx后可直接Run。PostLoadFcn调用initialize_pll_instances创建测试配置：A的Kp=100、Theta0=-0.2，B的Kp=250、Theta0=0.3，Ki/Kaw均为0，仅用于参数隔离验证。AngleScope的通道1/2是A/B角度，SpeedScope是A/B速度，trace依次为theta_A、omega_A、theta_B、omega_B。修改本次配置可用SimulationInput.setVariable('pllA',cfg,'Workspace','AngleTrackingInstancesTest')；运行waveform_analysis/run_pll_instance_validation执行3项隔离测试并保存数据。

Run后可在Scope工具栏点击Autoscale缩放时间/幅值，并打开Legend显示已命名的通道。StatusScope同时含0/1状态和0–100样本计数，自动纵轴可能让valid看起来很小；用信号选择器单独查看valid，或plot(out.trace.time,out.trace.signals.values(:,10))。计数不是电流/电压。
