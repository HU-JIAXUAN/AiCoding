# 死区误差、补偿与桥臂开关校验：运行与调参

## 1. 打开模型运行

```matlab
projectDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink";
addpath(fullfile(projectDir,"docs","scripts"), ...
    fullfile(projectDir,"model","app_models","Sensor","experiment","waveform_analysis"));
open_system(fullfile(projectDir,"model","lib","deadtime","src","DeadtimeTest.slx"));
```

点击Run，双击Scope观察。[参数/Scope表](../parameter/README.md)列出了实际块名、每个通道顺序、单位和来源。库用于复用；运行使用独立测试或装配模型。

## 2. 修改默认值

编辑 [deadtime_parameters.m](../parameter/deadtime_parameters.m)，保存后执行：

```matlab
initialize_motor_model("DeadtimeTest");
```

加载回调和该函数设置Model Workspace。重新初始化会重建参数与默认输入；base workspace同名结构不会覆盖它。只改某个配置字段不会自动重建已经生成的testStim数组。可在Model Explorer修改本轮工作区值；再次初始化会恢复参数文件默认值。

## 3. 只覆盖一轮实验

```matlab
o = struct();
o.deadtimeCfg = deadtime_parameters();
% 在这里修改o.deadtimeCfg中的字段。
r = run_motor_case("DeadtimeTest",o,[],0.03);
disp(r.parameters);
figure; plot(r.trace.time,r.trace.signals.values(:,1)); grid on;
```

run_motor_case用SimulationInput覆盖本轮，不将试验覆盖写回模型。第三参数[]选择默认输入，也可传N×输入列数矩阵；列顺序见[输入表](../parameter/README.md)。每行对应一个采样时刻，矩阵应覆盖停止时刻。SwitchingLegTest仅运行1ms、步长0.1µs，不沿用上面的长时示例。

Plant参数变化时，运行入口默认保持控制器增益不变，便于参数失配对照；如需重整定，将完整新电机结构传入current_parameters和motion_parameters，并将得到的结构一同放入o。更改Ts还要同步timingCfg.Ts，保持外环周期整数倍、Plant步长可整除控制周期，并重建输入数组。

## 4. 批量验证和观察指定case

```matlab
addpath(fullfile(projectDir,"model","lib","deadtime","waveform_analysis"));
summary = run_deadtime_validation();
data = load(fullfile(projectDir,"model","lib","deadtime","waveform_analysis","results.mat"));
names = fieldnames(data.records);
c = data.records.(names{1});
disp(c.parameters); disp(c.channels);
figure; plot(c.trace.time,c.trace.signals.values(:,1)); grid on;
```

全部06–14工况使用run_motor_validation()。原始MAT保留完整数据和参数；PNG/SVG代表图可能抽点，指标始终使用完整记录。Scope在批量运行后只显示最后一次仿真，比较时指定case加载。

## 5. 观察重点

平均误差使用硬电流符号，补偿使用有界平滑符号，并去掉三相共同分量。补偿加在SVPWM前，最终duty继续钳位。短时桥臂以计数器实现开通延迟、立即关断，死区按电流方向选择理想二极管续流。

桥臂电流由外部施加；没有器件结电容、反向恢复及真实零电流换流。开关测试核对假设下的符号、计数和均值，不证明真实过零精度。实际板卡需标定死区、压降和过零平滑区。

[搭建步骤](STEPS.md) · [波形解释](../waveform_analysis/ANALYSIS.md) · [Scope表](../parameter/README.md)

短时桥臂：直接打开src/SwitchingLegTest.slx并Run。results.mat包含switching_positive、switching_negative、switching_zero_deadtime、switching_short_pulse、switching_zero_crossing。CurrentBlend=0.01A是敏感性案例，不是实机推荐值。
