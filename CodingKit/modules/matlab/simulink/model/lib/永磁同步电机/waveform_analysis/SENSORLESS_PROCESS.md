# 共用SPMSM过程与测量Jacobian检查

| 记录字段 | 内容 |
|---|---|
| 模型文件 | src/pmsm_sensorless_step.m、src/pmsm_sensorless_measurement.m；本项为纯M函数，没有新增SLX |
| 参数文件 | parameter/pmsm_sensorless_parameters.m；检查点同时保存在JSON |
| 采样周期 | 50 μs |
| 求解器/步长 | Euler单步映射；有限差分核对，不运行Simulink求解器 |
| 工况 | 正转、反转、零速、下一步角度跨π，4个过程点与同4个测量点 |
| 数据文件 | waveform_analysis/sensorless_process_metrics.json |

R2026b运行[run_sensorless_process_validation.m](run_sensorless_process_validation.m)，4个过程Jacobian与4个测量Jacobian核对通过。每个状态方向采用中心差分，输出角差使用包角差值，避免跨π造成2π跳变误判。过程最大绝对元素偏差5.884e−10，测量最大偏差6.552e−12。JSON保存各点x/u/p及误差。

该检查证明实现的局部偏导与相同单步函数相符，不把8次纯M核对计入物理电机MIL。独立连续dq轨迹生成器不使用这些函数；EKF的25项独立输入MIL及完整协方差结果见[EKF分析](../../观测器/扩展卡尔曼/waveform_analysis/ANALYSIS.md)。原5项线性对象和14项高频对象结果不变。

参数、输入/状态/输出和无Scope说明见[过程参数页](../parameter/SENSORLESS_PARAMETERS.md)。复现时只添加本模块所需路径并调用检查脚本，不打开额外编辑器或图窗。
