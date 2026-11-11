# 离散速度给定与状态清除验证

| 记录字段 | 本次设置 |
|---|---|
| 模型文件 | `src/MotionControl.slx`、`src/SpeedProfileTest.slx` |
| 参数文件 | `parameter/speed_profile_parameters.m`、`parameter/refresh_speed_profile_parameters.m`、`parameter/speed_profile_test_parameters.m` |
| 采样周期 | 默认50 μs，另测1 ms；斜率用rad/s²，不能直接把每拍增量当成物理斜率 |
| 求解器/步长 | FixedStepDiscrete，步长等于profileCfg.Ts |
| 工况 | 正/负阶跃、上下限、非对称斜率、禁能后重新使能、复位优先和周期覆盖，共8项 |
| 数据文件 | `waveform_analysis/profile_results.mat`、`waveform_analysis/profile_metrics.json` |

R2026b隔离副本中8项通过，模型和数据已按SHA256核对后更新到正式目录；正式路径默认波形完全一致，原运动环3项回归也通过，见[核对记录](profile_verification.json)。50 μs、40 rad/s²对应每拍最多.002 rad/s；1 ms时每拍最多.04 rad/s，两者实际斜率相同。非对称案例验证上升60、下降20 rad/s²。大请求100/−100被限制到15/−15 rad/s。

禁能和复位立即清零输出及状态；重新使能首拍不超过对应方向一个允许增量，随后继续爬升。验收对连续有效区间检查斜率，对清零事件单独检查0，避免把明确的清状态误判为正常运行斜率超限。

本积木没有使用电机或位置估算器，因此这些测试不计作HFI闭环验证；接入App后的重启电流、估算资格和速度恢复需另做物理模型试验。新块追加前后原Position、Speed范围的拓扑/表达式快照一致，旧整机回归单独记录。
