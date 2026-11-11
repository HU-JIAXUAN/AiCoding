# EKF独立轨迹、拒绝资格与协方差分析

| 记录字段 | 内容 |
|---|---|
| 模型文件 | src/EkfObserverTest.slx、src/EkfObserver.slx |
| 参数文件 | parameter/ekf_parameters.m、parameter/ekf_test_parameters.m、parameter/refresh_kalman_parameters.m；共用对象定义在../pmsm_plant/parameter/pmsm_sensorless_parameters.m |
| 采样周期 | 默认50 μs；half_sample_time为25 μs |
| 求解器/步长 | FixedStepDiscrete；步长为cfg.Model.Ts |
| 工况 | 25项独立连续dq电压平衡轨迹，包括正反向、不同初值、加减速、跨零、测量和参数异常 |
| 数据文件 | waveform_analysis/results.mat、metrics.json；资格反例qualification_results.mat/qualification_metrics.json；并行实例instance_results.mat/instance_metrics.json |

## 数据与评分

R2026b完成25/25项MIL。输入由共用spmsm_estimation_fixture按连续dq电压平衡生成，不调用离散过程、Jacobian或观测器。规定的速度/电流轨迹提供独立对照，但没有模拟机械起转、电压限制、电流闭环及观测角接管。真实θ/ω仅供测试台记录与评分。

每个records字段保存configuration、test、truth、stimulus、实际time、N×50 trace、raw_log_shape、criteria和metric。SLX原始ToWorkspace数据为50×1×N；50列定义见[参数页](../parameter/README.md)，不可直接把第一维当作时间。记录按工况评分窗口计算RMS；默认0.35–0.5 s、爬升0.45–0.6 s、重启/复位0.55–0.7 s、反转0.85–1 s。正常工况角RMS<0.08 rad、速度RMS<8电角rad/s、窗口valid比例≥0.95，并核对全部已放行样本的角误差峰值<0.2 rad。爬升另要求t≥0.12 s持续valid。

| 工况 | 角RMS/rad | 速度RMS/(电角rad/s) | 窗口valid比例 | 说明 |
|---|---:|---:|---:|---|
| positive | 0.000819556 | 0.338644 | 1 | 首次资格20.4 ms |
| negative | 0.000821659 | 0.339033 | 1 | 方向先验−1；首次资格24.75 ms |
| speed_ramp | 0.001187477 | 0.652523 | 1 | 300→900电角rad/s；动态段持续资格通过 |
| dq_transient | 0.001440545 | 0.506984 | 1 | d/q电流平滑变化 |
| adc_noise | 0.000819152 | 0.339636 | 1 | 1 mA RMS合成噪声，固定种子42 |
| rs_mismatch | 0.012677185 | 3.444469 | 1 | 估计Rs比真实值高20%，id=−1 A |
| L_mismatch | 0.010389890 | 0.403451 | 1 | 估计L比真实值高20% |
| current_delay | 0.000646383 | 0.330143 | 1 | 电流落后一拍、电压不移位；不是已补偿采样链 |
| half_sample_time | 0.000405065 | 0.168228 | 1 | 刷新Q、滤波和资格计数；首次资格20.25 ms |
| flux_mismatch | 0.090311394 | 39.941967 | 0 | 估计磁链低10%；NIS均值102.746，超过25，按拒绝验收 |

50→25 μs时默认偏差约减半，提示Euler过程和连续轨迹离散化误差。上述数值属于指定轨迹与Q/R设置，不代表实际电机精度。execution_wall_s是电脑运行耗时，不能作为C2000任务耗时。

## 拒绝、故障与复位

flux_mismatch、zero_speed、below_operating、unknown_direction、wrong_direction五项都要求全程不放行。零速即使电流创新和配置σ很小，也没有反电势位置可观测性；20电角rad/s低于MinOmega=30。未知方向0不停止估计，禁止资格；错误方向−1与实际正转不一致，同样禁止资格。

invalid_direction=2触发故障2；nonfinite_voltage/current触发故障1，锁存后valid=0。电流异常本拍撤销资格，电压异常在下一预测保持拍体现。disable_restart、reset和reversal验证清状态/恢复P0、重新资格及正常方向变更保留位置历史。repeat_default与首次positive完整50列逐点相同。

另有两项合成资格检查：构造ω=−600而角历史变化率=+600、NIS=0、θ标准差0.01 rad的状态。默认MaxRateMismatch=60时valid=0，放宽到1e6后valid=1。这是书12.4.3所述相反速度分支的针对性反例，不是实际电机轨迹。

## 完整协方差与实例隔离

25项均逐拍检查16元素后验P：有限、与输出的四个对角元素一致、归一化对称误差<1e−12，并通过完整4×4 Cholesky正定检查。归一化尺度为[1 A,1 A,100 rad/s,1 rad]；实际最大对称误差为0。默认最小归一化Cholesky对角为0.0013903。σ和NIS反映配置统计模型，不是实际误差上界。

两个不同参数的完整EKF并行运行，A与默认单实例、B与其单独运行结果均逐点相同。B使用初角1.1 rad、初速900电角rad/s、测量标准差3 mA、过程方差密度翻倍；公开Mask工作区读回证实嵌套KalmanMeasurement实际接收到B配置。该检查不重复计入25项MIL。

从M源重新搭建两个SLX，并在正式目录回放默认工况，50列及时间与已保存数据完全一致；两个内嵌Function源与src的M文件一致，共用过程函数解析位置正确。证据见[verification.json](verification.json)。

## 看图与复现

- [ekf_capture.png](ekf_capture.png) / [SVG](ekf_capture.svg)：初始收敛、NIS/标准差与连续资格；Status使用双轴区分计数和标志。
- [ekf_dynamics.png](ekf_dynamics.png) / [SVG](ekf_dynamics.svg)：速度爬升、反转、电流变化及参数失配。
- [ekf_validity.png](ekf_validity.png) / [SVG](ekf_validity.svg)：零速、磁链偏差、错误方向、数据故障和50/25 μs对照。

三组图均从本次结果导出并逐张检查。运行、临时覆盖和重建方法见[USAGE.md](../build_process/USAGE.md)；实际10组Scope通道见[parameter/README.md](../parameter/README.md)。查看当前Scope后关闭，批量验证不打开编辑器或图窗。当前尚未完成该EKF的实际FOC接管、single/SIL、C2000构建或实机验证。
