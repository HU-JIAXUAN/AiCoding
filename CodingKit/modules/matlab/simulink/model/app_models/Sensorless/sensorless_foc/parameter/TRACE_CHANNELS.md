# 四组保存日志

来源名对应构建脚本中的块与输出口。单位采用SI；状态/逻辑为double记录。所有日志时间点严格相等，50 μs；日志与Scope是两种观察入口，不把日志列当成额外Scope。

## plant：13列

| 列 | 名称 | 单位 | 来源/作用 |
|---|---|---|---|
| 1 / 2 | id_true / iq_true | A | Electrical，真实转子坐标电流 |
| 3 | torque_true | N·m | Electrical，实际电磁转矩 |
| 4 / 5 | speed_true / position_true | 机械rad/s / rad | Mechanical |
| 6 / 7 | theta_true / omega_true | 电角rad / rad/s | Mechanical，仅供Plant和分析 |
| 8 | load_torque | N·m | 外部有符号负载 |
| 9 / 10 | vd_true / vq_true | V | Plant电气输入，真实转子坐标 |
| 11–13 | phase_current | A | i_a、i_b、i_c |

## observer：20列

| 列 | 名称 | 单位 | 来源/作用 |
|---|---|---|---|
| 1 / 2 / 3 | theta_hat / omega_hat / valid | 电角rad / rad/s / 0或1 | SMO估算输出 |
| 4 / 5 | emf_alpha / emf_beta | V | SMO滤波反电势 |
| 6 / 7 | i_hat_alpha / i_hat_beta | A | SMO电流状态 |
| 8 / 9 | injection_alpha / injection_beta | V | SMO滑模注入 |
| 10 / 11 / 12 | phase_measured / emf_magnitude / phase_error | rad / V / rad | 相位补偿输入、幅值、PLL误差 |
| 13–14 | current_ab | A | 实际采样Clarke电流 |
| 15–16 | observer_voltage | V | 实际三相电压重建并对齐反馈年龄 |
| 17 | observer_residual | A | norm(i_hat−i_measured) |
| 18 / 19 / 20 | enable / reset / direction | 0或1 / 0或1 / ±1 | 观测器实际输入 |

## controller：46列

| 列 | 名称 | 单位 | 来源/作用 |
|---|---|---|---|
| 1–2 | control_current | A | 在theta_used坐标下测量dq电流 |
| 3 / 4 | speed_reference / speed_error | 机械rad/s | 限斜率命令及速度误差 |
| 5 / 6 / 7 / 8 | torque_request / torque_allocated / torque_estimated / integral_torque | N·m | 速度PI、分配、估算及积分 |
| 9 | iq_closed | A | 闭环候选q轴参考 |
| 10–11 | reference | A | BlendDQ最终dq参考 |
| 12–13 | voltage_pi | V | CurrentPI输出 |
| 14–15 / 16–17 | integral_base / integral_state | V | 当前变换后的积分 / 上一积分状态 |
| 18–19 | voltage_residual | V | 执行链可实现电压残差 |
| 20 / 21 | theta_start / omega_start | 电角rad / rad/s | 启动器场角和爬升基速 |
| 22 / 23 | id_start / iq_start | A | 启动坐标电流参考 |
| 24 / 25 / 26 / 27 | ready / startup_mode / startup_fault / startup_elapsed | 0或1 / 整数 / 整数 / s | 启动状态 |
| 28 / 29 / 30 | theta_used / omega_base / omega_frame | 电角rad / rad/s / rad/s | 接管控制角、基速和规划坐标速度 |
| 31 / 32 / 33 / 34 / 35 | beta / handover_mode / handover_fault / acquired / run | 0..1 / 整数 / 整数 / 0或1 / 0或1 | 接管、故障和控制运行许可 |
| 36 / 37 / 38 | qualification_count / loss_count / phase_offset | 拍 / 拍 / rad | 接管连续资格、失锁计数及入口偏移 |
| 39 / 40 / 41 | delta_extra / track / auto_sampled | rad / 0或1 / 0或1 | 额外坐标纠正及慢拍AUTO判定 |
| 42 / 43–44 / 45–46 | voltage_alignment / voltage_selected / pi_residual | 0或1 / V / V | 电压对齐、最终所选dq请求、PI实际跟踪残差 |

## actuation：26列

| 列 | 名称 | 单位 | 来源/作用 |
|---|---|---|---|
| 1–6 | stimulus | 见参数页 | 六列实际工况输入，供逐拍核对 |
| 7–8 | voltage_request | V | Controller所选dq请求 |
| 9 | theta_control | 电角rad | Controller控制角 |
| 10–12 | phase_voltage | V | VoltageStage最终施加的三相平均电压 |
| 13–15 / 16–18 | duty_command / duty_applied | 0..1 | 计算占空比 / 执行延迟后的占空比 |
| 19 | voltage_scale | 0..1 | 线性调制电压限制比例 |
| 20–21 | voltage_residual | V | 回到控制坐标的可实现电压残差 |
| 22–24 / 25–26 | measured_phase_current / measured_current_ab | A | 采样三相 / Clarke电流 |

具体程序列映射由[sensorless_foc_channels.m](sensorless_foc_channels.m)产生，[读取器](../waveform_analysis/read_sensorless_foc_result.m)验证列数并生成`columns`字段。[参数与Scope](README.md)。
