# 桥耦合 PMSM 波形分析

| 字段 | 记录（路径相对于模块目录） |
|---|---|
| 模型文件 | `src/PMSMBridgePlant.slx`、`src/PMSMBridgePlantTest.slx` |
| 参数文件 | `parameter/pmsm_bridge_parameters.m`、`parameter/bridge_test_parameters.m` |
| 采样周期 | 默认对象与记录5μs；half_step为2.5μs |
| 求解器/步长 | FixedStepDiscrete；电气后向Euler、机械前向Euler，默认5e-6s |
| 工况 | 下表14项物理动态和1项错误模式拒绝；18组纯M另计 |
| 数据文件 | `waveform_analysis/bridge_results.mat`、`bridge_metrics.json`、`bridge_kernel_checks.mat/json`、`bridge_invalid_mode.json` |

| 工况 | 点数 | 电流向量峰值(A) | 末速度(机械rad/s) | 回馈能量(J) | 最大M调度回放差 |
|---|---|---|---|---|---|
| coast_forward | 2001 | 0 | 79.84016 | 0 | 0 |
| coast_reverse | 2001 | 0 | -79.84016 | 0 | 0 |
| release_forward | 2001 | 3 | 79.894135 | 0.0050315258 | 0 |
| release_reverse | 2001 | 3 | -79.89426 | 0.0050268186 | 0 |
| active_short | 2001 | 15.696197 | 30.716291 | 0 | 0 |
| pwm_locked | 2001 | 14.52502 | 0 | 0 | 0 |
| rectify_forward | 1201 | 22.248606 | 400 | 5.2016643 | 0 |
| rectify_reverse | 1201 | 22.309153 | -400 | 5.203484 | 0 |
| coast_short_release | 12001 | 15.651941 | 29.481224 | 0.09538068 | 0 |
| low_bus_rectify | 4001 | 1.9382667 | 111.68328 | 0.41240755 | 0 |
| zero_friction_coast | 2001 | 0 | 80 | 0 | 0 |
| half_step | 24001 | 15.651218 | 29.480962 | 0.09588572 | 0 |
| spmsm_release | 2001 | 3 | 79.885634 | 0.0040817897 | 0 |
| zero_voltage_PWM_is_short | 2001 | 15.696197 | 30.716291 | 3.1726288e-17 | 0 |
| invalid_mode | 0 | — | — | — | — |

零电流、反电势低于母线的全关断工况保持零电流滑行；3A初始电流在关断后先经二极管衰减，不在切换时清零。PWM [.5,.5,.5]与主动短路的电流/转速/转矩轨迹一致，均出现约15.696A峰值；因此“零请求电压”不能代替关断。高转速全关断仍有约22.3A整流电流并向刚性母线回馈，关断并不保证永远零电流。

18组纯M检查包含：独立SPMSM中性点二分法240点，最大电流差约1.4211e-14A；IPMSM互补条件240点，最大桥功率残差约6.5377e-11W。自由转子能量缺陷在5/2.5/1.25μs步长下约为−2.6629e-4/−1.3606e-4/−6.8290e-5J，比例1.957/1.992，符合一阶步长收敛；不宣称旋转全过程严格无数值耗散。

电流输出只依赖当前状态，逐点检查下一时刻相电流等于前一拍next_phase_current；桥功率核对使用同一隐式区间的电压和电流。M回放只证明模型连接/调度与嵌入源一致；独立物理依据来自RL解析递推、中性点二分法、互补条件和能量检查。

| 波形 | 阅读内容 |
|---|---|
| [滑行→短路→释放](bridge_modes.png) / [SVG](bridge_modes.svg) | 主动短路时电流和制动；释放时短暂二极管回馈 |
| [3A电流释放](bridge_release.png) / [SVG](bridge_release.svg) | 放大首0.3ms，观察电流连续衰减；MAT仍保存完整10ms数据 |
| [高速整流](bridge_rectifier.png) / [SVG](bridge_rectifier.svg) | 上下二极管导通、母线负电流和能量回馈 |

当前是常参数线性磁路、三线星接、理想刚性母线与示例PWL二极管。未执行Simscape交叉对照，未拟合板卡/电机数据，不含母线过压、开关纹波、反向恢复与寄生电容。还没有接入旧无位置App或带速捕获；C2000实机保护结论另验。

[参数/Scope](../parameter/BRIDGE_PARAMETERS.md) · [搭建](../build_process/BRIDGE_BUILD.md) · [运行](../build_process/BRIDGE_USAGE.md) · [来源核对](bridge_verification.json)
