# Math 模型运行与调参

## 1. 打开并运行默认工况

```matlab
moduleDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink/model/lib/math";
addpath(fullfile(moduleDir,"src"),fullfile(moduleDir,"parameter"), ...
    fullfile(moduleDir,"build_process"),fullfile(moduleDir,"waveform_analysis"));
open_system(fullfile(moduleDir,"src","ClarkeParkTest.slx"));
```

也可在 MATLAB 中直接双击测试模型。加载回调设置默认 ctCfg 和 ctStim。点击 Run，默认运行 0.1 s、50 Hz、峰值 5 A 的三相输入；角度和信号同步，应看到 d=5 A、q≈0。

双击 ForwardSignals 看 abc/αβ0/dq，双击 InverseSignals 看重建信号，RoundTripErrors 看重建减原输入，ElectricalAngle 看电角度。图例和自动缩放已开启；各向量元素的准确顺序在 [参数与 Scope 表](../parameter/README.md)。误差组可能自动缩放至 1e-15 量级，应结合纵轴和 1e-12 A 容差阅读。

从 [Clarke 源库](../src/clarke/README.md) 或 [Park 源库](../src/park/README.md) 拖入需要的变换块。ClarkePark.slx 提供既有库链接入口。使用 ClarkeParkTest 运行往返变换。

## 2. 修改默认输入或参数

长期默认值编辑 [clarke_park_parameters.m](../parameter/clarke_park_parameters.m)，保存后调用：

```matlab
initialize_clarke_park_test("ClarkeParkTest");
```

或者关闭后重新打开测试模型。初始化将重新生成 ctCfg 和 ctStim；仅在 Model Explorer 修改 Amplitude 等字段不会自动改写已经生成的输入数组。

以下示例只覆盖一轮实验：角度比信号超前 30°，应得到 d≈4.330127 A、q≈−2.5 A。

```matlab
cfg = clarke_park_parameters();
cfg.AngleOffsetRad = pi/6;
t = (0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
phase = 2*pi*cfg.FrequencyHz*t + cfg.InitialAngleRad;
abc = cfg.Amplitude*cos(phase+[0,-2*pi/3,2*pi/3]);
stim.time = [];
stim.signals.values = [abc,phase+cfg.AngleOffsetRad,zeros(numel(t),3)];
stim.signals.dimensions = 7;
in = Simulink.SimulationInput("ClarkeParkTest");
in = in.setVariable("ctCfg",cfg,"Workspace","ClarkeParkTest");
in = in.setVariable("ctStim",stim,"Workspace","ClarkeParkTest");
out = sim(in);
figure; plot(out.ctTrace.time,out.ctTrace.signals.values(:,7:8));
grid on; legend("d","q"); xlabel("Time (s)"); ylabel("A");
```

若要使用界面点击 Run 运行同一自定义工况，可把 cfg/stim 赋给模型工作区：

```matlab
mw = get_param("ClarkeParkTest","ModelWorkspace");
assignin(mw,"ctCfg",cfg);
assignin(mw,"ctStim",stim);
```

模型使用 Model Workspace 中的值。在 base workspace 单独建立同名 ctCfg 不会覆盖它。重新初始化会恢复参数文件中的默认配置与输入。

## 3. 独立运行反变换

仍使用上面的七列输入结构，将模式设为 1，并提供第 5–7 列命令：

```matlab
cfg = clarke_park_parameters();
cfg.UseIndependentInverse = 1;
t = (0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;
theta = 2*pi*cfg.FrequencyHz*t;
d_cmd = 3*ones(size(t));
q_cmd = 2*ones(size(t));
zero_cmd = zeros(size(t));
stim.time = [];
stim.signals.values = [zeros(numel(t),3),theta,d_cmd,q_cmd,zero_cmd];
stim.signals.dimensions = 7;
in = Simulink.SimulationInput("ClarkeParkTest");
in = in.setVariable("ctCfg",cfg,"Workspace","ClarkeParkTest");
in = in.setVariable("ctStim",stim,"Workspace","ClarkeParkTest");
out = sim(in);
figure; plot(out.ctTrace.time,out.ctTrace.signals.values(:,15:17));
grid on; legend("a reconstructed","b reconstructed","c reconstructed");
xlabel("Time (s)"); ylabel("A");
```

此时 InverseSignals 是关注对象，RoundTripErrors 比较的是新命令生成的 abc 与前三列的原 abc，不要求为零。后续将反变换用于电压命令时，所有 dq/αβ/abc 数值单位一起改为 V，θ 仍为 rad。

## 4. 观察零序为什么要保留

使用正常往返模式，在默认 abc 的三列都叠加同一个信号，例如 1.2*cos(3*phase)。ZeroSequenceGain=1 时可重建完整 abc；改为 0 后，误差为原零序的负值。这是有意丢弃信息的结果。

已保存的完整演示在 [zero_sequence.png](../waveform_analysis/zero_sequence.png)。三线制零和电流可将零序作为 0；任意三相测试量则应检查三相和后再解释重建误差。

## 5. 运行全部验证并读取数据

```matlab
summary = run_clarke_park_validation();
data = load(fullfile(moduleDir,"waveform_analysis","results.mat"));
disp(fieldnames(data.cases));
c = data.cases.mixed_zero;
disp(c.cfg); disp(c.trace.channels);
figure; plot(c.trace.time,c.trace.values(:,18:20)); grid on;
legend("error a","error b","error c"); xlabel("Time (s)"); ylabel("A");
```

脚本以参数文件为生成基线，构造 13 项明确工况并执行断言，保存输入、实际配置、20 列数据、JSON 指标及五组 PNG/SVG 图。结果与判断标准见 [ANALYSIS.md](../waveform_analysis/ANALYSIS.md)。再次运行会覆盖这些结果；Scope 显示最后一次仿真，不代表全部工况。

单次 out.ctTrace 为 Structure With Time，时间在 time，20 列数值在 signals.values。批量 cases 的 trace.time/values/channels 分别保存时间、矩阵和列名。第 9 列单位 rad，其余列为本测试的 A；不要把全部 20 列当成同一单位画在一张纵轴上。

## 6. 常见现象

| 现象 | 检查与解释 |
|---|---|
| 期望 d 为正，却看到 q 或符号相反 | 核对 abc 相序、角度是 rad 还是 degree、是否选择 d 轴对齐 |
| 修改 FrequencyHz 或 Amplitude 后波形没变 | 重新初始化，或重新生成并覆盖 ctStim |
| 模式改成 1 后反变换全为零 | 默认独立命令为零，填写输入第 5–7 列 |
| 反变换后相差一个共同分量 | 检查 zero_used 与 ZeroSequenceGain |
| 完整往返看起来有微小误差 | 看纵轴量级并与 1e-12 A 容差比较，不按自动缩放后的线高判断 |
| d/q 没有变为常值 | 检查 θ 是否与信号同步；非平衡/谐波输入的 dq 本来可以变化 |

[返回模块](../README.md)
