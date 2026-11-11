# 运行与修改

从工程根`simulink`执行：

```matlab
addpath(fullfile(pwd,'docs','scripts'))
initialize_motor_paths()
module = fullfile(pwd,'model','app_models','Sensorless','sensorless_fw');
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'), ...
        fullfile(module,'waveform_analysis'))
p = sensorless_fw_parameters();
record = run_sensorless_fw_case(p);
```

`record`保存本次参数、实际输入及plant/observer/controller/allocation/actuation/guard六组time/trace/columns。运行器隐藏加载并关闭自己加载的模型；如果已经打开该App，则保留其窗口。

需要看Scope时只打开当前App：

```matlab
open_system(fullfile(module,'src','SensorlessFieldWeakeningFOC.slx'))
initialize_sensorless_fw('SensorlessFieldWeakeningFOC')
```

点击Run，在Controller打开CurrentAllocationScope、AllocationVoltageScope和SpeedLoopScope；Plant打开TrueCurrentScope、BusVoltageScope；StartInterlock打开PermitScope。各Scope精确通道在[参数页](../parameter/README.md)，不将电角速度与机械速度直接叠成同单位曲线。观察结束关闭Scope和子系统。

一次参数覆盖示例：

```matlab
p = sensorless_fw_parameters();
p.focCfg.Direction = -1;
p.focCfg.SpeedReference = -210;
p.focCfg.LoadTorque = -0.1;
p.fwCfg.BusTimes = [0 1.4 2];
p.fwCfg.BusValues = [48 46 48];
p.experimentCfg.Duration = 2.6;
p = refresh_sensorless_fw_parameters(p);
stimulus = sensorless_fw_stimulus(p);
record = run_sensorless_fw_case(p,stimulus);
```

这一覆盖只影响本次SimulationInput；直接点GUI Run使用模型工作区默认值。修改`parameter/sensorless_fw_parameters.m`后执行`clear sensorless_fw_parameters; rehash`及初始化函数，再运行GUI。修改电机、环路周期后还需同步电流环/EEMF/PLL/启动/切换的相关配置；refresh只更新表、向量与派生值，不自动替用户重新整定控制器。

启停与反转事件通过7列`stimulus.signals.values`修改。方向列只接受±1；使能/复位/观测使能只接受0或1；母线必须正有限。长时间低于允许母线、电机/采样参数错误或过大的参考可能触发模型断言；不要通过关闭断言把无效输入记为验证通过。

查看具体数值：

```matlab
c = record.allocation.columns;
plot(record.allocation.time,record.allocation.trace(:, ...
    [c.id_reference c.iq_reference c.id_fw])); grid on
legend('id reference','iq reference','FW state')
```

复跑验证输出到自己新建的结果目录，避免覆盖本次归档：

```matlab
out = fullfile(tempdir,'sensorless_fw_my_run'); mkdir(out)
run_sensorless_fw_validation(out)
run_sensorless_fw_edges(out)
```

边界默认执行仿真；`run_sensorless_fw_edges(archivedFolder,true)`仅对已保存的同参数/同输入记录重新分析。历史首次边界报告使用不成立的“加载滑行末速度>100”检查；归档重分析按每拍机械方程界及事件状态连续性判断，原始MAT/错误报告保留。当前脚本直接仿真也使用修正后的判据。

已有SLX的构建器拒绝覆盖。需要证明从M可重建时，在隔离副本中只复制本模块M文件，保留空src，并加载正式工程路径；运行`build_sensorless_fw`。构建器会从正式EEMF模板组装本App。不要删除正式SLX后直接尝试重建。

[模块](../README.md) · [波形](../waveform_analysis/ANALYSIS.md)
