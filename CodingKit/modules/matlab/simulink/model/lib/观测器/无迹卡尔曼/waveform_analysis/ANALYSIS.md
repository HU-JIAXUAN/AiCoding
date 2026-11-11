# UKF独立轨迹、协方差与数值边界分析

| 记录字段 | 内容 |
|---|---|
| 模型文件 | src/UkfObserver.slx、src/UkfObserverTest.slx |
| 参数文件 | parameter/ukf_parameters.m、parameter/refresh_ukf_parameters.m、parameter/ukf_test_parameters.m；共用SPMSM过程在../pmsm_plant/parameter/pmsm_sensorless_parameters.m |
| 采样周期 | 默认50 μs；half_sample_time为25 μs |
| 求解器/步长 | FixedStepDiscrete；步长cfg.Model.Ts |
| 工况 | 29项独立连续dq电压平衡轨迹，另有21项纯M数值检查及并行实例检查 |
| 数据文件 | waveform_analysis/results.mat、metrics.json；numerical_results.mat/numerical_metrics.json；instance_results.mat/instance_metrics.json |

## MIL结果

29/29项通过。真实轨迹由独立连续dq电压平衡生成，不调用离散过程或观测器；真实θ/ω只用于测试台评分。该输入没有闭合机械起转、电压限制或电流控制接管。

正常工况按窗口要求角RMS<.08 rad、速度RMS<8电角rad/s、valid比例≥.95，且所有放行点的角误差峰值<.2 rad。默认窗口.35–.5 s、爬升.45–.6 s、重启/复位.55–.7 s、反转.85–1 s；爬升另要求t≥.12 s持续valid。完整P逐拍有限、与对角输出一致、归一化对称误差<1e−12并通过4×4 Cholesky正定检查。本组29项double轨迹中numeric_repairs均为0。

| 工况 | 角RMS/rad | 速度RMS/(电角rad/s) | 窗口valid比例 | 说明 |
|---|---:|---:|---:|---|
| positive | .000818994 | .339156525 | 1 | 首次资格20.4 ms |
| negative | .000822222 | .338519581 | 1 | 首次资格24.75 ms |
| speed_ramp | .001187212 | .652945579 | 1 | 300→900电角rad/s，动态段持续资格通过 |
| dq_transient | .001439983 | .507497192 | 1 | d/q电流变化 |
| adc_noise | .000818590 | .340146660 | 1 | 1 mA RMS合成噪声，种子42 |
| rs_mismatch | .012677751 | 3.443954182 | 1 | 估计Rs高20%，真实id=−1 A |
| L_mismatch | .010390595 | .404126836 | 1 | 估计L高20% |
| current_delay | .000645820 | .329630074 | 1 | 仅电流落后一拍，非已补偿采样链 |
| half_sample_time | .000404497 | .168734203 | 1 | 周期25 μs，首次资格20.225 ms |
| sigma_alpha_small | .000818994 | .339156624 | 1 | Alpha=.2，首次资格20.3 ms |
| sigma_kappa_two | .000818993 | .339156469 | 1 | Kappa=2，首次资格20.5 ms |
| flux_mismatch | .090310777 | 39.942542202 | 0 | 磁链低估10%，按NIS拒绝资格验收 |

25 μs的默认误差约为50 μs一半，体现Euler过程与连续轨迹离散化的影响。Alpha/Kappa的稳态差异很小，不能据这组匹配模型证明UKF普遍优于EKF。σ和NIS是配置P0/Q/R下的统计指标，不是实际误差上界；execution_wall_s是电脑仿真耗时，不能作为C2000时序。

## 拒绝、故障与复位

flux_mismatch、zero_speed、below_operating、unknown_direction、wrong_direction五项全程不放行。零速无法从反电势辨认绝对位置；低于30电角rad/s、未知方向或方向不一致都不能作为可用点。方向变化清连续资格但保留位置状态，禁能/复位清状态与P，repeat_default与首次默认50列逐点一致。

invalid_direction和故意损坏的UT打包Alpha触发故障2；非有限电压/电流触发1；初始θ标准差1 rad使sigma点超过默认角范围，触发3。故障时valid=0；数值故障恢复配置初值/P0并锁存，需禁能或复位后重新资格。记录中协方差仍逐拍检查，不以故障标志代替数据有限性检查。

## 数值与实例检查

21项纯M检查采用闭式SPMSM三角矩、公开对象的限定比较、线性测量等价性和数值反例。对本机公开UKF对象与公开权重公式的差异，单独保存可手算案例，见[REFERENCE_BEHAVIOR.md](REFERENCE_BEHAVIOR.md)。可修复协方差案例为合成输入，不计入物理MIL。

并行A使用默认参数，B使用初角1.1 rad、初速900电角rad/s、Alpha=.6、Kappa=2、3 mA测量标准差及翻倍过程方差密度。A与默认单实例、B与其独立运行分别逐点相同；公开Mask工作区读回确认外层预测配置和内层共享测量都收到B参数。并行检查不重复计入29项。

## 相同输入对照与计算量

25个共同工况均逐项核对真实输入9列、实际时间和公共Settings完全一致。默认EKF角/速RMS为.000819556/.338643502，UKF为.000818994/.339156525；当前条件下接近。Rs/L失配的主要偏差也接近，不据这些轨迹宣称某种滤波器普遍更优。

正常启用预测时，EKF调用过程1次并使用Jacobian做A·P·Aᵀ+Q；UKF调用过程9次，做两次完整Cholesky检查，若触发修复，每拍分解总尝试数最多12。该计数来自实际源码流程，不能换算为C2000周期数。不同MIL运行中保存的execution_wall_s不作为受控性能排名；目标时间和目标内存均为NOT_MEASURED。

从M源重新搭建及正式目录回放默认50列/时间逐点一致，共享Measurement实际链接和来源正确，见[verification.json](verification.json)。

## 图与读取数据

- [收敛图](ukf_capture.png)：初始状态、创新、NIS/σ和连续资格；标志与计数使用双轴。
- [动态图](ukf_dynamics.png)：爬升、跨零反转、电流变化和Rs/L/数据年龄影响。
- [有效性图](ukf_validity.png)：零速、磁链失配、错误方向、数据故障及25/50 μs。
- [EKF/UKF对照图](ukf_ekf_comparison.png)：相同输入初始收敛/爬升、RMS及Alpha/Kappa对资格初段的影响。



每项records含configuration、test、truth、stimulus、time、trace、raw_log_shape、criteria、metric。trace为N×50；原始ToWorkspace数据为50×1×N。完整P按列展开在34–49列，重建使用reshape(trace(k,34:49),4,4)。10组Scope、端口和列号逐项见[参数页](../parameter/README.md)。运行、覆盖和重建见[USAGE.md](../build_process/USAGE.md)。

本模块当前证据属于独立输入MIL与纯M/实例检查；物理FOC接管、完整single/SIL及C2000构建/实机验证另行记录。
