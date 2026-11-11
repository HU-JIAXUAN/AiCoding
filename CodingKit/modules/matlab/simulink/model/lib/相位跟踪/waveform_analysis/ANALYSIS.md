# PLL 验证记录

- 模型文件：src/AngleTrackingTest.slx
- 参数文件：parameter/angle_tracking_parameters.m
- 采样周期：50 µs
- 求解器/步长：FixedStepDiscrete / 50 µs
- 工况：正负恒速、包角、加速、速度变化、相位噪声、幅值丢失、复位、禁能、限速、初始误差、全程无幅值
- 数据文件：`results.mat`（运行验证后生成）、[waveform_analysis/metrics.json](metrics.json)

MATLAB：26.2.0.3433840 (R2026b) Update 1。12/12项MIL通过，结构检查healthy；图和原始数据已保存。指标窗口为0.25–0.30 s。

| 工况 | 角度RMS / rad | 速度RMS / 电角rad/s | 有效比例 | 结果 |
|---|---|---|---|---|
| positive | 4.509e-15 | 1.142e-11 | 1 | 通过 |
| negative | 4.473e-15 | 1.147e-11 | 1 | 通过 |
| wrap | 4.679e-15 | 1.113e-11 | 1 | 通过 |
| acceleration | 8.691e-7 | 0.0001257 | 1 | 通过 |
| speed_step | 3.640e-9 | 0.000001444 | 1 | 通过 |
| phase_noise | 0.001556 | 5.207 | 1 | 通过 |
| amplitude_dropout | 5.297e-7 | 0.00008868 | 1 | 通过 |
| reset | 8.757e-9 | 0.000002496 | 1 | 通过 |
| disable | 8.580e-9 | 0.000002480 | 1 | 通过 |
| speed_limit | 1.848 | 1671 | 0 | 通过 |
| initial_error | 4.625e-15 | 1.101e-11 | 1 | 通过 |
| no_amplitude | 1.912 | 200.0 | 0 | 通过 |

正常跟踪工况验收线为角度RMS<0.04 rad、速度RMS<10 rad/s、有效比例>95%，仅适用于本合成测试基线。speed_limit/no_amplitude按有界及无效行为验收，表中大误差不是跟踪合格，也不能用于算整体平均精度。

相位噪声标准差0.015 rad、随机种子17，稳态角度RMS约0.001556 rad，速度RMS约5.207电角rad/s。解析恒速输入的接近机器精度误差仅核对符号/离散实现，不代表实际电机位置精度。

[幅值丢失图](dropout.png)中0.12–0.17 s幅值为0：角状态保持、速度输出0、valid立即失效。真实相位继续变化，所以包角误差会在±π处跳变；恢复后重新捕获并延时置valid。reset/disable均检查当拍初值输出和随后恢复。

所有输入样本均为有限值；本版不接受NaN/Inf。尚未从电压/电流估算转子，不是Sensorless闭环、C2000代码或实机证据。
