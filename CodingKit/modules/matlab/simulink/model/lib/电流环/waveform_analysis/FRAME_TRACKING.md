# FrameTrackingPI 独立验证

- 模型文件：src/CurrentControl.slx、src/FrameTrackingPITest.slx。
- 参数文件：parameter/frame_pi_test_parameters.m，引用parameter/current_parameters.m及相邻pmsm_plant/inverter参数；每例实际参数保存于MAT。
- 采样周期：默认50µs，sample_time案例100µs。
- 求解器/步长：FixedStepDiscrete / currentCfg.Ts，无连续Plant。
- 工况：下表10项；输入事件按整数采样索引定义，记录输入与请求逐点一致。
- 数据文件：waveform_analysis/frame_pi_results.mat、waveform_analysis/frame_pi_metrics.json；同目录frame_transfer、frame_proportional、frame_aw的PNG/SVG。

R2026b Update 1，正式src路径重新加载后10/10通过，原电流环6项回归也通过。指标和数据入口为 [run_frame_pi_validation.m](run_frame_pi_validation.m)，原电流环结果保留于 [metrics.json](metrics.json)。

| 案例 | 实际检查 | 结果 |
|---|---|---|
| normal_equivalence | track=0，时变误差和外部残差，新旧PI逐点比较 | 电压和积分差0 V |
| pure_frame_change | Kpd≠Kpq、非零FF，额外旋转0.8rad；把新总电压旋回原物理坐标 | 最大差2.22e-16 V；未做状态转换的朴素比较有>0.1V误差 |
| proportional_during_tracking | 始终track=1、delta=0，误差在10ms真实阶跃；Ki/Kaw=0 | 输出等于Kp.*e，误差0 V，没有取消比例响应 |
| feedforward_transfer | FF从0变为[3;-2]V，仅转换期间track=1，之后退出 | 总请求保持0 V，积分贡献变为[-3;2]V；当前误差为0 |
| positive_aw | 强制d轴误差+1A持续2–20ms，圆限制2V | 积分趋于+0.42920367V；解析稳态误差4.32e-9V |
| negative_aw | 相同条件、误差-1A | 对称结果，稳态误差4.32e-9V |
| without_aw | 相同强制误差，Kaw=0 | 积分积累到28.2743V，最终可行电压仍不超过2V |
| reset | 非零状态/原始FF下复位，之后重启 | 同拍PI/FF门控输出清零，下一状态0；与旧PI一致 |
| disable | 禁能10ms后重新使能 | 结果同上；外部残差仍可有输入，模块不消费它更新非零状态 |
| sample_time | Ts=100µs时重复普通PI比较 | 差0 V |

### 如何读波形

连接复核发现工具的掩码可见性限制：直接对掩码内单个MATLAB Function执行model_check时，工具误报外部端口未连接。实际11个端口的公共Line句柄均有效，仿真也通过；将库另存到隔离目录、仅对副本关闭Mask后，整个FrameTrackingPI子系统的model_read可见全部连接，model_check为healthy。正式库的Mask保留，源文件与保存后的函数代码逐字一致。这不是修改正式模型来绕过未连接端口。

[frame_transfer.png](frame_transfer.png) 中d/q分量在坐标转换时变化是预期的；是否连续必须把总电压旋回同一物理坐标比较，不能要求两组不同坐标的数字相等。[frame_proportional.png](frame_proportional.png) 中误差阶跃后电压立刻响应，用于检查持续track是否错误地消掉比例项。

[frame_aw.png](frame_aw.png) 的请求电压约3.57V、可行电压2V，回算残差为负。这里电流误差由测试输入强制保持，不是Plant闭环。非零稳态积分是Ki*e与Kaw*r平衡的结果；20ms误差归零后积分可保持，不应把这张图解释为电机电流恢复或保护验证。

这10项只证明离散状态转换、回算、复位及日志时序。源文件中like-cast不构成single、SIL或C2000证据；实际电机切换、转矩跳变和角度延迟继续由App验证。测试模型默认UseInternalLimit=0，AW案例明确覆盖为1，避免把外部伪残差误认为闭环限制。

[模块入口](../README.md) · [搭建与运行](../build_process/FRAME_TRACKING.md) · [参数/Scope](../parameter/FRAME_TRACKING.md)
