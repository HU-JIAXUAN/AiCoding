# 四种物理观测FOC的运行与改参

在工程根`simulink`运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'))
initialize_motor_paths()
module = fullfile(pwd,'model','app_models','Sensorless','sensorless_foc');
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'), ...
        fullfile(module,'waveform_analysis'))
kind = 'mras'; % 或 'ekf'、'ukf'、'sigmoid'
p = extension_foc_parameters(kind);
r = run_extension_foc_case(kind,p);
```

返回结构保存本次p、实际七列输入、主机耗时及六组time/trace/columns。运行器隐藏加载并关闭自己加载的模型；已有模型窗口保留，不打开多余Scope。

GUI查看时只打开当前一份：

```matlab
spec = extension_foc_spec(kind);
open_system(fullfile(module,'src',[spec.model '.slx']))
initialize_extension_foc(spec.model,kind)
```

点击Run，先看Controller/SpeedLoopScope和StateScope，再看Observer内的EstimateAngleScope、ResidualScope与各算法资格指标。实际物理电流看Plant/TrueCurrentScope；控制坐标电流看Controller/CurrentScope，两者使用的角度不同。互锁看StartInterlock/ObservedVoltageScope和PermitScope。通道顺序见[完整表](../parameter/EXTENSION_PARAMETERS.md)；观察结束关闭Scope/子系统再切下一模型。

反转单次覆盖（对应已验证reverse场景）：

```matlab
p = extension_foc_parameters(kind);
p.focCfg.Direction = -1;
p.focCfg.SpeedReference = -80;
p.focCfg.LoadTorque = -0.1;
p = refresh_extension_foc_parameters(p);
r = run_extension_foc_case(kind,p);
```

实际母线由`fwCfg.BusTimes/BusValues`或七列输入第7列给定。恒36V场景需要同时将名义`inverterCfg.Vdc`和`fwCfg.BusValues`设36；仅改名义值不会改实际母线输入。七列输入依次是速度、负载、总使能、复位、方向、观测使能、实际Vdc。旧三份六列刺激不能直接套用。

观测电阻偏差按算法结构修改：

```matlab
% MRAS / sigmoid
p.observerCfg.Rs = 1.15*p.pmsmCfg.Rs;
% EKF / UKF 则使用：
% p.observerCfg.Model.Rs = 1.15*p.pmsmCfg.Rs;
p = refresh_extension_foc_parameters(p);
r = run_extension_foc_case(kind,p);
```

两种结构分开使用，不要把不属于该算法的字段加入后当作已生效。refresh保留显式观测模型偏差；真实pmsmCfg继续同步到bridgeCfg。模型、控制器和观测器都有自己的物理参数职责，修改真实电机后若要保持匹配，需要同步观测参数并重新整定相关环路。

修改磁盘默认M后，执行`clear extension_foc_parameters; rehash`并重新初始化当前模型，再点击GUI Run。SimulationInput单次覆盖不会写回SLX/磁盘默认值，GUI直接Run使用模型工作区配置。

取出波形：

```matlab
c = r.observer.columns;
plot(r.observer.time,r.observer.trace(:,[c.omega_hat c.valid])); grid on
```

这两列单位不同，正式分析时分别作图。机械估速为omega_hat/P；Plant按5μs记录，Observer按50μs记录，比较真值时按时间索引对齐，不能直接相减不同长度矩阵。

复跑10项并保存到新目录：

```matlab
out = fullfile(tempdir,['my_' kind '_physical_foc']); mkdir(out)
run_extension_foc_validation(kind,out)
```

第三参数可选场景名，例如`{'reverse','observer_loss'}`。场景、阈值和分析分别在[工况](../parameter/extension_foc_cases.m)、[阈值](../parameter/extension_foc_validation_parameters.m)、[分析函数](../waveform_analysis/analyze_extension_foc.m)。归档MAT可用于离线复核；不要覆盖正式40项记录后混淆不同配置。

构建器拒绝覆盖已有SLX。重建在隔离目录中仅复制本批M文件，保留空src并初始化正式工程依赖，然后运行`build_extension_foc(kind)`；原模板和lib继续复用。工程提供的是明确选择的四份App，运行中更换观测算法的状态转换尚未实现。

[搭建](EXTENSION_BUILD.md) · [参数/Scope](../parameter/EXTENSION_PARAMETERS.md) · [波形](../waveform_analysis/EXTENSION_ANALYSIS.md)
