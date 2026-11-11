# 当前可执行配置

默认参数分别归各模块parameter所有；单轮实验只传需要覆盖的结构字段，不建立顶层参数副本。

```matlab
projectDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink";
addpath(fullfile(projectDir,"docs","scripts"));
open_system(fullfile(projectDir,"model","app_models","Sensor","experiment","src","MotorExperiment.slx"));
o = struct();
o.experimentCfg = struct('Mode',1,'SpeedReference',40,'LoadTorque',0.1);
r = run_motor_case('MotorExperiment',o,[],1.2);
```

前馈与死区对照分别设置o.feedforwardCfg.Enable，以及o.deadtimeCfg.ModelEnable/CompensationEnable；保持对象、给定和控制器相同后比较结果。run_motor_case返回实际parameters、inputs与trace，原始数据不依赖base workspace。

电流/速度/位置模式为0/1/2，实验开始前选择。更改Plant参数时默认保留控制器增益；若希望重新整定，显式传入current_parameters(完整电机结构)和motion_parameters(完整电机结构)的结果。Ts、保持、延迟与步长的限制见[整机教程](../../model/app_models/Sensor/experiment/build_process/USAGE.md)。

其他入口：[全部45项验证](../scripts/run_motor_validation.m)、[整机参数与52列Scope](../../model/app_models/Sensor/experiment/parameter/README.md)。

## 导航

- [MOTOR_PARAMETER_SCHEMA.md](MOTOR_PARAMETER_SCHEMA.md)

[返回项目入口](../../README.md)
