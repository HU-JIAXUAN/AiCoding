# 指标定义

第15步指标见[MTPA/弱磁分析](../../model/lib/MTPA弱磁/waveform_analysis/ANALYSIS.md)：peak_reference_current_A为全时段参考dq向量模长最大值；oracle_error_A为31个转矩采样点相对独立数值优化的模长最大绝对差；minimum_feasible_voltage_margin_V只在feasible=true处取最小值，若没有可行点则JSON为null；tail_current_error_rms_A使用末0.1s的dq合成误差RMS。final_speed_error_rad_s为最后记录点请求与真值的绝对差。速度PI积分以N·m记录，不等同实测转矩。

- `rise_time_s`：从指定低阈值到高阈值的首次上升时间；阈值须由实验定义。
- `settling_time_s`：最后一次进入指定稳态误差带的时间；稳态带由场景给出。
- `overshoot_pct`：相对阶跃幅度的超调，零/负幅值场景需明确定义。
- `steady_state_error`：稳态窗口内参考值和测量均值的差，可带单位。
- `rms_error`：在明确窗口内的跟踪误差均方根。
- `saturation_ratio`：饱和状态为真的采样点比例；需指定参考采样率。
- `peak_i_A`, `peak_v_V`：指定信号通道与时间窗内绝对峰值。
- `simulation_wall_time_s`：电脑仿真墙钟时间；`controller_exec_time_us`：按明确方法测得的目标算法时间。ISR deadline 与测试最大观测值单独记录，不能直接称为已证明的 WCET。

指标阈值在调参/工况定义完成后审定；计划包不伪造基准数值。

## 06–14当前实际指标

- current_iae_A_s：对完整记录积分∫(|id_ref−id_truth|+|iq_ref−iq_truth|)dt。
- recovery_iae_A_s：电流台架从0.012s恢复时刻开始的相同L1误差积分。
- tail_current_rms_A：sqrt(mean(ed²+eq²))，是dq合成误差RMS，不是某一相电流的RMS；rms_window_start_s/end_s记录准确窗口。短工况可覆盖全程，不自动称为稳态。
- final_current_error_A：末点两轴误差绝对值最大者。final_speed_error_rad_s只在速度/位置模式计算，final_position_error_rad只在位置模式计算，其余JSON为null。
- energy_balance_error_J：锁定电角速度工况中，输入电能减铜耗，与0.75·(Ld·id²+Lq·iq²)磁储能变化比较。
- half_step_difference_A：Plant步长5µs与2.5µs的同拍电流最大差，区别于控制周期变化。
- 单桥臂mean_pole_voltage_V在去掉起始两个周期后，以完整PWM周期的样本均值计算；shoot_through_count为高低门极同时真的记录点数。

执行断言和实际阈值在[run_motor_validation.m](../scripts/run_motor_validation.m)。本次没有把未计算的带宽/相位裕度或目标执行时间标成通过。
