# 线性反电势与EEMF验证记录

| 字段 | 本次内容 |
|---|---|
| 模型文件 | src/EmfObserver.slx、src/LinearEmfTest.slx、src/EemfObserverTest.slx |
| 参数文件 | parameter/emf_parameters.m、parameter/emf_test_parameters.m |
| 采样周期 | 50 μs |
| 求解器/步长 | FixedStepDiscrete，50 μs，R2026b |
| 工况 | 每种电机16项，共32项；每项0.4 s |
| 数据文件 | waveform_analysis/results.mat、metrics.json及四组PNG/SVG |

## 怎样验证

独立解析对象从dq电压平衡计算电压和αβ电流；观测器只接收电压、电流、方向、使能和复位。真实包角/速度仅接入测试台的日志、误差和Scope。验证逐样本核对9列输入、采样网格和全部有限值，健康工况在最后0.1 s计算包角RMS、速度RMS及valid比例，限值为0.12 rad、3电角rad/s、95%。

模型在独立进程和临时副本中生成，候选28项通过后，经SHA256核对迁入正式src。正式路径重新加载、两处内嵌MATLAB Function与src/emf_predict.m一致性、默认编译运行均通过；随后在正式路径完成32项全量验证，包括保持观测器使能的零速和极低速。

## 实际结果

32项全部通过。下表为正常估算工况的末尾0.1 s指标；实际未取整数值见[metrics.json](metrics.json)。

| 工况 | SPMSM角RMS(rad) | IPMSM角RMS(rad) | 最大速度RMS(电角rad/s) |
|---|---|---|---|
| +200 rad/s | 0.0003465 | 0.0003545 | <1e-8 |
| -200 rad/s | 0.0003447 | 0.0003528 | <1e-8 |
| +600 rad/s | 0.0024952 | 0.0027922 | <1e-8 |
| 150→600 rad/s加速 | 0.0161951 | 0.0160404 | 0.03873 |
| id/iq变化 | 0.0006329 | 0.0006314 | <1e-8 |
| 真实Rs增加20%，估算Rs不变 | 0.0281012 | 0.0278046 | <1e-8 |
| α电压增加0.03 V偏置 | 0.0042706 | 0.0041946 | 0.85943 |
| 电流噪声标准差0.005 A，seed=42 | 0.0003666 | 0.0003746 | 0.08736 |
| 暂停后恢复 | 0.0003464 | 0.0003543 | 0.000362 |
| 单拍复位后恢复 | 0.0003465 | 0.0003545 | <1e-6 |
| 实际速度反转、方向输入同步变化 | 0.0003447 | 0.0003528 | <1e-6 |

这些工况的尾段valid比例均为1。固定Rs偏差产生约0.028 rad的相位偏差，单纯看速度接近真实值不能发现它，须同时看AngleScope和Current/ResidualScope。

## 无效工况怎样解释

每种电机另有5项：错误方向、零速direction=0、零速保持direction=+1、5 rad/s保持direction=+1、非法direction=2。

错误方向时角度约差π，而速度仍约等于真实速度；direction*omega_hat门限使valid=0。方向0或2时模块停用并清状态。保持使能的零速/低速测试仍执行电流和反电势状态估计，尾段反电势幅值低于0.5 V、电流残差RMS小于0.05 A，valid=0。此时位置误差较大不算跟踪性能通过；检查通过的是模块没有把缺少位置有效信息的状态标成已锁定。

## 看哪些波形

| 图 | 内容 |
|---|---|
| [spmsm_positive.png](spmsm_positive.png) / [SVG](spmsm_positive.svg) | 线性SPMSM的初始电流状态与PLL收敛 |
| [ipmsm_positive.png](ipmsm_positive.png) / [SVG](ipmsm_positive.svg) | 含凸极项的IPMSM估算 |
| [ipmsm_current_ramp.png](ipmsm_current_ramp.png) / [SVG](ipmsm_current_ramp.svg) | 电流变化时扩展反电势模型的过渡 |
| [ipmsm_reversal.png](ipmsm_reversal.png) / [SVG](ipmsm_reversal.svg) | 实际速度和已知方向同步反转、清状态后重新收敛 |

Scope六组实际通道及22列数据在[参数页](../parameter/README.md)。这些反转输入来自独立已知工况，不是已经实现的任意带速方向识别或整机反转策略。数据中的wall_time_s包括主机编译/运行开销，不作为C2000执行时间。
