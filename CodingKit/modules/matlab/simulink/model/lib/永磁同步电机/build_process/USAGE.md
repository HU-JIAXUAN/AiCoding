# PMSM 数学电机与刚性负载：运行与调参

## 1. 打开模型运行

```matlab
projectDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink";
addpath(fullfile(projectDir,"docs","scripts"), ...
    fullfile(projectDir,"model","app_models","Sensor","experiment","waveform_analysis"));
open_system(fullfile(projectDir,"model","lib","pmsm_plant","src","PMSMPlantTest.slx"));
```

点击Run，双击Scope观察。[参数/Scope表](../parameter/README.md)列出了实际块名、每个通道顺序、单位和来源。库用于复用；运行使用独立测试或装配模型。

## 2. 修改默认值

编辑 [pmsm_parameters.m](../parameter/pmsm_parameters.m)，保存后执行：

```matlab
initialize_motor_model("PMSMPlantTest");
```

加载回调和该函数设置Model Workspace。重新初始化会重建参数与默认输入；base workspace同名结构不会覆盖它。只改某个配置字段不会自动重建已经生成的testStim数组。可在Model Explorer修改本轮工作区值；再次初始化会恢复参数文件默认值。

## 3. 只覆盖一轮实验

```matlab
o = struct();
o.pmsmCfg = pmsm_parameters();
% 在这里修改o.pmsmCfg中的字段。
r = run_motor_case("PMSMPlantTest",o,[],0.03);
disp(r.parameters);
figure; plot(r.trace.time,r.trace.signals.values(:,1)); grid on;
```

run_motor_case用SimulationInput覆盖本轮，不将试验覆盖写回模型。第三参数[]选择默认输入，也可传N×输入列数矩阵；列顺序见[输入表](../parameter/README.md)。每行对应一个采样时刻，矩阵应覆盖停止时刻。SwitchingLegTest仅运行1ms、步长0.1µs，不沿用上面的长时示例。

Plant参数变化时，运行入口默认保持控制器增益不变，便于参数失配对照；如需重整定，将完整新电机结构传入current_parameters和motion_parameters，并将得到的结构一同放入o。更改Ts还要同步timingCfg.Ts，保持外环周期整数倍、Plant步长可整除控制周期，并重建输入数组。

## 4. 批量验证和观察指定case

```matlab
addpath(fullfile(projectDir,"model","lib","pmsm_plant","waveform_analysis"));
summary = run_pmsm_plant_validation();
data = load(fullfile(projectDir,"model","lib","pmsm_plant","waveform_analysis","results.mat"));
names = fieldnames(data.records);
c = data.records.(names{1});
disp(c.parameters); disp(c.channels);
figure; plot(c.trace.time,c.trace.signals.values(:,1)); grid on;
```

全部06–14工况使用run_motor_validation()。原始MAT保留完整数据和参数；PNG/SVG代表图可能抽点，指标始终使用完整记录。Scope在批量运行后只显示最后一次仿真，比较时指定case加载。

## 5. 观察重点

电气部分保存 id、iq；机械部分保存机械速度和位置。整机将电磁转矩与电角速度闭合。独立测试台分别驱动两部分，便于对照解析解；测试输入第4列是独立机械转矩，不会自动改成电气部分的转矩。

线性磁路、恒定R/L/磁链、单惯量与黏性阻尼；不含磁饱和、铁耗、齿槽、弹性轴和温度模型。参数是自定义仿真夹具，没有实际电机辨识来源。

[搭建步骤](STEPS.md) · [波形解释](../waveform_analysis/ANALYSIS.md) · [Scope表](../parameter/README.md)
