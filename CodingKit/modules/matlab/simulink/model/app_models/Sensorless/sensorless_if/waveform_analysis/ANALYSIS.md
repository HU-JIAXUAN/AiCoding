# I-f 波形分析

| 核对项 | 条件 |
| --- | --- |
| 模型 | [SensorlessIF.slx](../src/SensorlessIF.slx)，平均桥＋合成 SPMSM |
| 参数 | [可执行 M](../parameter/if_app_parameters.m)，48 V、40 Hz，1.5 s 加 0.05 N·m |
| 采样 | 控制 62.5 μs，对象 12.5 μs，稳态评分用脚本中的末窗 |
| 求解器 | 固定步长离散；另将对象步长减半复核默认结果 |
| 工况 | 13 项，包含可跟随、可保护以及预期失步 |
| 数据 | [指标 JSON](results.json)、[默认图](default.svg)、[过载图](overload.svg)、两份浏览 CSV |

默认工况对象末窗平均机械速度 62.769076 rad/s，参考 62.831853 rad/s，速度误差 RMS 0.614358 rad/s，峰值电流 3.02559 A，末窗相位行程 0.108336 rad。相位行程用于看滑移；不能用绝对相位差推断位置精度。

| 工况 | 预期分类 | 末窗速度 RMS (rad/s) | 电流峰值 (A) | 末故障码 |
| --- | --- | --- | --- | --- |
| default | tracking | 0.61436 | 3.0256 | 0 |
| reverse | tracking | 0.61436 | 3.0256 | 0 |
| initial_angle | tracking | 1.0071 | 3.0437 | 0 |
| reduced_bus | tracking | 0.61436 | 3.0256 | 0 |
| frequency_limit | tracking | 0.49476 | 3.0537 | 0 |
| load_step | tracking | 1.287 | 3.0539 | 0 |
| moving_forward_refused | refused | 10.286 | 0 | 3 |
| moving_reverse_refused | refused | 10.286 | 0 | 3 |
| current_trip | current_trip | 25.176 | 0.80238 | 1 |
| reset_refused | event_refused | 13.012 | 3.0058 | 3 |
| disable_refused | event_refused | 13.012 | 3.0058 | 3 |
| overload | counterexample | 190 | 7.6588 | 0 |
| voltage_shortage | voltage_counterexample | 75.089 | 3.3682 | 0 |

过载、低母线是**预期反例**；通过意味着复现了限定工况中的异常。I-f 过载可能在未达到过流阈值的情况下滑移。观察窗口只根据电流和端电压作启动判断，不能识别所有剩余转速。默认结果属于同一合成电机的不同控制方式，不能据此判定一种算法普遍更好。

无位置估计、闭环接管、C2000 和实机验证不在本轮范围。
