# 运行 EEMF / 磁链无位置 FOC

在MATLAB R2026b中进入工程根目录，先运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
p = observer_foc_parameters('eemf');
r = run_observer_foc_case('eemf',p);
```

返回`r.plant`、`r.observer`、`r.controller`、`r.actuation`，各自含`time`、`trace`、`columns`和`definitions`；`r.parameters`保存实际配置。运行器只在需要时隐藏加载指定模型，并关闭本次加载的模型；已由你加载的模型保留。

修改本次仿真参数：

```matlab
p = observer_foc_parameters('eemf');
p.emfCfg.BandwidthHz = 250;
r = run_observer_foc_case('eemf',p);

p = observer_foc_parameters('flux');
p.fluxCfg.LeakHz = 8;
r = run_observer_foc_case('flux',p); % 自动刷新泄漏/去直流系数
```

修改默认值则编辑[observer_foc_parameters.m](../parameter/observer_foc_parameters.m)；共同参数入口仍为[sensorless_foc_parameters.m](../parameter/sensorless_foc_parameters.m)。更改电机Ld/Lq必须遵守当前共同SPMSM基线；凸极整机验证另行接入无位置MTPA/弱磁。改Ts时需同步电流、测量、PLL、观测、启动、接管及整倍数速率，运行器检查这些周期。

手动打开一份模型运行和看Scope：

```matlab
module = fullfile(pwd,'model','app_models','Sensorless','sensorless_foc');
open_system(fullfile(module,'src','FluxSensorlessFOC.slx'));
initialize_observer_foc('FluxSensorlessFOC','flux'); % 改默认参数后重新载入
```

点击Run，依次进入Observer和Controller查看Scope。[通道说明](../parameter/OBSERVER_PARAMETERS.md)逐项说明源端口和单位。`EstimateSpeedScope`是电角速度；机械速度比较可用保存数据或[绘图函数](../waveform_analysis/plot_observer_foc_results.m)。切换研究模型时关闭先前模型和Scope即可。

```matlab
plot_observer_foc_results(r,'custom'); % 输出custom的PNG/SVG，图窗自动关闭
c = r.observer.columns;
theta = r.observer.trace(:,c.theta_hat);
quality = r.observer.trace(:,c.observer_residual);
```

完整验证会写入本模块waveform_analysis中对应的结果文件，按需运行：

```matlab
run_observer_foc_validation('eemf');
run_observer_foc_validation('flux');
% 单独检查指定场景；会覆盖该观测器的结果文件：
run_observer_foc_validation('flux',{'positive','observer_loss'});
```

重建使用[build_observer_foc.m](build_observer_foc.m)，已有目标SLX时明确拒绝覆盖。在独立副本或空输出目录重建，关闭源模型编辑器；不要删除正式模型来尝试重建。仿真时避免在基础工作区用`pi`作为普通变量；可用`whos pi`检查名称冲突。

[参数](../parameter/README.md) · [波形结果](../waveform_analysis/OBSERVER_ANALYSIS.md)
