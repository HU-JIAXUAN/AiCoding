# 运行、调参与观察

在 MATLAB 中将当前文件夹切到工程根目录 `simulink`，执行：

```matlab
addpath(fullfile(pwd,'docs','scripts'))
initialize_motor_paths
open_system('SensorlessIF')
```

点击 Run。双击 `SpeedScope` 看软件频率对应的同步速度与真实机械速度，`AngleScope` 看环绕相位差，`StatusScope` 看阶段与故障。再看 CurrentTrackingScope 的给定、反馈和积分。

修改 [参数 M](../parameter/if_app_parameters.m)后，在当前模型执行 `initialize_if_app('SensorlessIF')` 再运行。临时工况建议只改结构体，不改模型：

```matlab
p = if_app_parameters();
p.experimentCfg.Frequency = 20;
r = run_if_app_case(p);
plot(r.time,r.trace(:,r.columns.speed_mechanical));
xlabel('Time (s)'); ylabel('Mechanical speed (rad/s)');
```

要重跑全部工况，从工程根目录执行下列命令；它会刷新[结果目录](../waveform_analysis/README.md)。

```matlab
addpath(fullfile(pwd,'model','app_models','Sensorless','sensorless_if','waveform_analysis'))
run_if_app_validation()
```

若需从 M 重建，先关闭本 App，再执行 `build_if_app()`；会重写本 App 的 SLX，不需要重建其他组件。
