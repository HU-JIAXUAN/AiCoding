# 运行Sigmoid SMO、修改参数和看波形

## 默认运行

从任意当前目录可运行：

```matlab
module = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink/model/lib/观测器/滑模";
addpath(fullfile(module,"build_process"));
open_system(fullfile(module,"src","SigmoidSlidingModeObserverTest.slx"));
initialize_sigmoid_smo_test('SigmoidSlidingModeObserverTest');
in = Simulink.SimulationInput('SigmoidSlidingModeObserverTest');
out = sim(in);
```

也可直接打开SLX点击Run。只打开当前Test；右击Observer查看Mask内实现，不必同时展开多份库。结束后用close_system关闭当前模型，保留MATLAB主窗口。

默认工况0.3s、50µs固定离散步长、6001个样本。配置在模型工作区，Base Workspace同名变量不负责覆盖它。Scope和24列日志见[信号页](../parameter/SIGMOID_PARAMETERS.md)。

## 改默认值与做一次失配实验

永久默认值改parameter中的sigmoid_smo_parameters.m；改物理参数/斜率后refresh会重算A/B/局部极点。本地sigmoid_smo_pll_parameters.m同步Ts及MinMagnitude，可在此调整本实例PLL；工况、噪声、事件和验收窗改sigmoid_smo_test_parameters.m。改后重新执行initialize_sigmoid_smo_test，再Run，不需要改SLX中的数字。

一次只改变观测电阻、保持原测试输入：

```matlab
cfg = sigmoid_smo_parameters();
cfg.Rs = 0.6;
cfg = refresh_sigmoid_smo_parameters(cfg);
in = Simulink.SimulationInput('SigmoidSlidingModeObserverTest');
in = in.setVariable('sigmoidCfg',cfg,'Workspace','SigmoidSlidingModeObserverTest');
out = sim(in);
plot(out.trace.time,out.trace.signals.values(:,24));
ylabel('wrapped angle error (rad)');
```

改变真实电机时要重新生成输入；不能同时改观测和对象电阻后把它称为参数失配。改变周期后同步PLL、输入时间轴、求解器步长，并重新设计增益/资格时间。

## 批量入口

```matlab
initialize_sigmoid_smo_paths();
report = run_sigmoid_smo_validation();       % 22项，覆盖跟踪、拒绝/故障和噪声限制
kernel = run_sigmoid_kernel_checks();        % 10项纯M，含single核冒烟
instance = run_sigmoid_instance_check();     % 临时双实例，与各自单独运行对照
comparison = compare_sigmoid_basic();       % 同输入/K/小信号斜率/PLL的6次对照
plot_sigmoid_smo_results();
```

批量脚本不打开编辑器和图窗；实例模型只在内存创建并关闭，不另存第三份SLX。完整报告会重写同名sigmoid_results.mat/metrics.json，分析指定案例应从records读取，不依赖Scope最后一次显示。

## 读结果

```matlab
data = load(fullfile(module,"waveform_analysis","sigmoid_results.mat"));
r = data.records.high_positive;
plot(r.time,r.trace(:,[8,10]));               % 真实/估计电角度
clf; plot(r.time,r.trace(:,24));              % 看完前图后复用同一图窗，观察包角误差
clf; stairs(r.time,r.trace(:,12));            % 再复用图窗观察valid
```

上面画图命令逐段执行，观察完成后再清当前图，不同时展开多个图窗。10mA限制案例为records.noise_10mA_qualification_drop。它的角误差仍小，但单个PLL误差越界会重新计100拍，导致5ms资格中断；不要把“角度图看着接近”当成连续资格满足。

供App使用时拖入SigmoidSlidingModeObserver/SigmoidSMO，两个Mask分别绑定本实例cfg和trackerCfg。输入电压必须是与电流年龄对齐的实际作用电压，direction来自经验证的方向管理；当前独立验证不等于已经把本算法接入无位置整机。
