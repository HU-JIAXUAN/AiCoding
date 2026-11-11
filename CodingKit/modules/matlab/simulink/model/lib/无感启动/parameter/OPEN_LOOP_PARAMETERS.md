# OpenLoopDrive 参数与信号

## 配置参数

[open_loop_drive_parameters.m](open_loop_drive_parameters.m) 定义默认值；[refresh_open_loop_drive_parameters.m](refresh_open_loop_drive_parameters.m) 刷新采样计数、初始状态与打包向量。库实例使用 `openLoopCfg`；测试工况由 [open_loop_drive_test_parameters.m](open_loop_drive_test_parameters.m) 定义。

| 向量序号 | 字段 | 默认/单位 |
| --- | --- | --- |
| 1–4 | Ts, Kind, MaximumFrequency, FrequencySlew | 62.5 μs，1 I-f/2 V/f，80 Hz，40 Hz/s |
| 5–8 | ObserveTicks, StartVoltageMaximum, StartCurrentMaximum, ObserveTimeoutTicks | 800 点（0.05 s），0.25 V，0.2 A，8000 点（0.5 s） |
| 9–10 | AlignTicks, AlignRampTicks | 4000 点（0.25 s），1600 点（0.1 s） |
| 11–13 | AlignAmplitude, RunAmplitude, AmplitudeSlew | I-f：2 A、3 A、40 A/s；V/f：0.5 V、运行按曲线、50 V/s |
| 14–16 | VfSlope, VfBoost, VoltageFraction | 0.219911 V/Hz，0.5 V，0.96/√3 |
| 17–18 | CurrentTrip, Theta0 | 12 A，0 rad（V/f App 覆盖为 −π/2） |

## 输入信号

按库端口 1–6，也是 Test `trace` 第 1–6 列：频率命令 Hz，使能 0/1，复位 0/1，采样电流矢量幅值 A，采样端电压矢量幅值 V，实际母线 V。

## 过程变量

状态向量 1–8：阶段、阶段计数、软件电角度 rad、软件电频率 Hz、给定幅值 A/V、故障码、连续低电压电流计数、幅值目标受限标志。计数按控制周期更新。低幅值信号只提供静止资格，不能证明转子位置或转速。

## 输出信号

按库端口 1–8，也是 Test `trace` 第 7–14 列：软件电角度 rad、软件电频率 Hz、幅值 A/V、PWM允许 0/1、阶段、故障码、阶段经过时间 s、幅值受限 0/1。阶段 0/1/2/3/7 为待机/观察/对齐/运行/故障。故障 0/1/2/3/4 为无故障/过流/输入非法/观察超时/阶段非法。

## Scope 通道

| Scope | 顺序（从 1 开始） |
| --- | --- |
| AngleScope | 软件电角度 rad |
| FrequencyScope | 电频率命令 Hz、软件电频率 Hz |
| AmplitudeScope | 幅值 A/V、幅值受限标志 |
| StatusScope | 使能、复位、PWM允许、阶段、故障 |
| ObservationScope | 电流幅值 A、端电压幅值 V、母线电压 V、阶段时间 s |
