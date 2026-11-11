# DiscretePID 运行、调参与观察

本页对应已有的模型文件，不需要先运行脚本重新搭建模型。模型内部原理见 [STEPS.md](STEPS.md)，每个参数、信号和 Scope 通道见 [parameter/README.md](../parameter/README.md)。

## 1. 打开正确的模型

在 MATLAB 命令窗口执行：

```matlab
moduleDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink/model/lib/离散并联PID";
addpath(fullfile(moduleDir,"src"),fullfile(moduleDir,"parameter"), ...
    fullfile(moduleDir,"build_process"),fullfile(moduleDir,"waveform_analysis"));
open_system(fullfile(moduleDir,"src","DiscretePIDTest.slx"));
```

也可在 MATLAB 当前文件夹中直接打开 src/DiscretePIDTest.slx。它的 PostLoadFcn 调用 initialize_discrete_pid_test，把 pidCfg、pidStim 放入 DiscretePIDTest 的 Model Workspace，并加入模块运行路径。

DiscretePID.slx 是供复用的 Library，运行实验使用 DiscretePIDTest.slx。测试模型中的 PIDUnderTest 保留到 DiscretePID/Controller 的库链接。

## 2. 运行默认工况

1. 在测试模型中核对 Stop Time 为 3。Model Settings 的 Solver 为 Fixed-step / discrete，步长表达式为 pidCfg.Ts。
2. 点击 Run。默认 Ts=0.001 s、Kd=0，所以首先观察 PI 行为。
3. 双击 Waveforms，点击 Autoscale 查看全部曲线；启用 Legend，并按参数说明中的通道顺序识别曲线。
4. 首先对比通道 1 command 与 6 plant_y，再看 3 u、4 u_unsat、5 x_i、7 saturated。默认工况中，0.1–1 s 输出顶在上限，1 s 给定下降后退出饱和。
5. 通道 9 x_d 默认全为零。通道 8 是官方参考输出，默认工况全程使能且不复位，因此可与通道 3 比较。

如需取得可直接分析的数据，可在命令窗口运行：

```matlab
in = Simulink.SimulationInput("DiscretePIDTest");
out = sim(in);
t = out.pidTrace.time;
v = out.pidTrace.signals.values;
figure;
plot(t,v(:,[1 6])); grid on;
legend("command","plant y"); xlabel("Time (s)");
```

命令窗口运行的输出显式保存在 out；通过 Simulink Run 按钮生成的 SimulationOutput 变量名以界面设置为准。SaveTrace 的记录变量名为 pidTrace，不是 ScopeData。

## 3. 查看模型内部怎么计算

打开 src/DiscretePID.slx。在 Controller 上右击 Mask → Look Under Mask；直接双击通常先打开掩码参数窗口。内部的三个子系统是：

- OutputStage：比例、P+I+D 求和、限幅、限幅差和输出使能。
- IntegralUpdate：积分变化率、乘 Ts、与本拍状态相加、下一状态选择和 Unit Delay。
- DerivativeFilter：误差差分、一阶滤波、斜率状态复位和乘 Kd。

Unit Delay 的输出代表本拍保存值，输入代表准备写入的下一拍值。对照 [搭建图](STEPS.md) 沿线阅读，就能将块与离散方程逐项对应。修改源算法时先解锁库，修改后保存库并重跑验证。

## 4. 修改参数的三种方式

### 临时调参并用界面点击 Run

先打开测试模型，再执行：

```matlab
mw = get_param("DiscretePIDTest","ModelWorkspace");
cfg = discrete_pid_parameters();
cfg.Kd = 0.02;
cfg.Tf = 0.01;
assignin(mw,"pidCfg",cfg);
```

随后点击 Run，观察通道 9。也可在 Model Explorer 的 DiscretePIDTest → Model Workspace 中查看和编辑 pidCfg。这里改的是当前加载模型的值。

### 一次仿真覆盖参数

```matlab
cfg = discrete_pid_parameters();
cfg.Kaw = 0;  % 观察关闭回算后，通道 5 的积分积累和退出饱和过程
in = Simulink.SimulationInput("DiscretePIDTest");
in = in.setVariable("pidCfg",cfg,"Workspace","DiscretePIDTest");
out = sim(in);
figure;
plot(out.pidTrace.time,out.pidTrace.signals.values(:,[3 5 6])); grid on;
legend("u","x i","plant y"); xlabel("Time (s)");
```

SimulationInput 对这一轮仿真覆盖模型工作区变量，不改参数文件，也不依赖 base workspace 中同名的 pidCfg。

### 修改长期默认值

编辑 [parameter/discrete_pid_parameters.m](../parameter/discrete_pid_parameters.m)，保存后调用：

```matlab
initialize_discrete_pid_test("DiscretePIDTest");
```

或者关闭后重新打开测试模型。初始化会重新生成 pidCfg 和默认 pidStim；仅修改 .m 文件不会自动刷新已加载的模型工作区。每次加载都会以这个文件为默认值来源。

Ki 的单位为 1/s，模型内已经乘 Ts；Kd 的单位为 s，差分和滤波也在模型内完成。改变 Ts 后，应重新运行实验检查动态响应。改变 Ts 的同时应重新生成 pidStim，使输入行数与新采样周期和仿真时长相配。

## 5. 修改输入：单独观察微分

下面是一轮可独立执行的纯滤波微分实验，0.05 s 时误差从 0 变成 0.2：

```matlab
cfg = discrete_pid_parameters();
cfg.ClosedLoop = 0;
cfg.Kp = 0; cfg.Ki = 0; cfg.Kd = 0.02; cfg.Kaw = 0;
cfg.Tf = 0.01;
t = (0:cfg.Ts:0.3)';
command = zeros(size(t));
command(51:end) = 0.2;
sampled = @(x) struct('time',[], ...
    'signals',struct('values',x,'dimensions',1));
stim.command = sampled(command);
stim.enable = sampled(true(size(t)));
stim.reset = sampled(false(size(t)));
in = Simulink.SimulationInput("DiscretePIDTest");
in = in.setVariable("pidCfg",cfg,"Workspace","DiscretePIDTest");
in = in.setVariable("pidStim",stim,"Workspace","DiscretePIDTest");
in = in.setModelParameter("StopTime","0.3");
out = sim(in);
figure;
plot(out.pidTrace.time,out.pidTrace.signals.values(:,[2 9])); grid on;
legend("error","x d"); xlabel("Time (s)");
```

当前 Ts=1 ms，所以第 51 行对应 0.05 s。x_d 首拍约为 Kd*0.2/(Tf+Ts)=0.363636，之后按 Tf/(Tf+Ts)=10/11 衰减。把 Kd 改为 0 再运行，x_d 应全为零。

复位/禁能实验也使用相同结构：将 stim.enable.signals.values 的一段设为 false，或将 stim.reset.signals.values 的一段设为 true。若要在界面 Run 中使用自定义输入，执行 assignin(mw,"pidStim",stim)，并把 Stop Time 调成对应时长。重新初始化会恢复默认输入。

复位时应看到 u/u_unsat/saturated/x_d 当拍为零、x_i 为 X0。上一误差仍按拍记录；重新使能第一拍从 X0 开始积分，微分响应由那一拍相对上一拍的误差变化决定。官方参考没有接入同样的 enable/reset，因此这些工况不按通道 3/8 的差判断通过。

## 6. 跑全部测试、查原始数据

```matlab
summary = run_discrete_pid_validation();
data = load(fullfile(moduleDir,"waveform_analysis","results.mat"));
disp(fieldnames(data.cases));
c = data.cases.derivative_step;
disp(c.cfg); disp(c.trace.channels);
figure; plot(c.trace.time,c.trace.values(:,[3 8 9])); grid on;
legend("custom PID","official reference","x d");
```

脚本运行 12 个固定验证工况，保存每次 cfg、输入 stim、九通道 trace、MAT/JSON 指标以及五组 PNG/SVG 波形。工况表、阈值和解释见 [ANALYSIS.md](../waveform_analysis/ANALYSIS.md)。再次运行会覆盖这些结果文件。

回归工况使用参数默认文件并在相应工况中覆盖字段；原有解析 PI 工况以默认 Kd=0 为基线，微分工况显式设为 0.02。修改默认增益、初值或 Kd 后，原工况假设和性能断言可能不再成立；单次调参先使用前述 SimulationInput。Scope 显示最后一次仿真，五组导出波形和 results.mat 才覆盖全部工况。

## 7. 常见现象对应哪里

| 现象 | 检查位置 |
|---|---|
| 改了 .m 但波形没变 | 刷新 initialize_discrete_pid_test，检查 Model Workspace 的 pidCfg |
| 在 base workspace 改 pidCfg 没效果 | 模型使用自己的 Model Workspace，按第 4 节覆盖或赋值 |
| x_d 一直为零 | 默认 Kd=0；恒定误差的滤波微分也会逐渐归零 |
| 看不到积分变大的曲线 | Scope 点击 Autoscale，或用 out.pidTrace 第 5 列作图 |
| 官方曲线与自建曲线看似只有一条 | 全程使能且同配置时两条通常重合，检查第 3/8 列差值 |
| 跑了全部测试却在 Scope 只看到一组 | Scope 当前只保留最后一次仿真，使用 cases 选择其他工况 |
| 复位第一拍 Delay 里仍看到旧积分 | 输出已由 Switch 选择 X0；Delay 在下一拍输出新写入的 X0 |

[返回模块](../README.md)
