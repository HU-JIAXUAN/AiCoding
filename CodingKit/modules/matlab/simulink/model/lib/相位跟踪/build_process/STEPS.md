# PLL 搭建步骤与各部分作用

1. 新建 AngleTracking Library，建立 PLL 子系统，端口、状态和算法都用标准块实现。
2. phase 减去 theta_state，经 sin/cos/atan2 得到包角相位误差，避免跨 ±π 时出现接近 2π 的假误差。
3. 比例通道 Kp×error 与积分状态相加形成原始速度；Saturation 限制到 ±OmegaMax。
4. 积分器用 Unit Delay 保存状态，前向欧拉更新为 integral[k+1] = clamp(integral[k] + Ts×(Ki×error + Kaw×(omega_limited−omega_raw)))。限幅残差负责回算，积分状态另有同范围限幅。
5. theta_state[k+1] = wrap(theta_state[k] + Ts×omega_limited[k])。对外 theta_e_hat 是 k 时刻状态，不提前冒充下一拍角度。
6. enable=0 或 reset=1 时，输出角度回到 Theta0、速度为 0、valid=0，下次状态回到初值。幅值不足时保持角度和积分状态、速度输出 0、锁定计数清零；不以除法下限伪造可观测性。
7. 有幅值且误差不超过 LockError 连续达到 LockSamples 后 valid=1；任一条件失效立即 valid=0。这是本 PLL 的相位资格判据，不能单独证明转子观测正确。
8. 独立测试台用From Workspace提供输入：Interpolate=off、OutputAfterFinalValue=Holding final value；输入时间轴覆盖StopTime。三组Scope观察角度、速度和状态，12列trace保存到SimulationOutput。

标准块：Inport/Outport、Gain、Sum、Unit Delay、Switch、Saturation、Trigonometric Function、Relational Operator、Logical Operator、Data Type Conversion；测试台另有 Mux/Demux、Scope、From/To Workspace。无隐藏 MATLAB Function 算法。

PLL子系统另加可求值的Mask参数pllCfg：MaskVariables为pllCfg=@1;，默认表达式pllCfg。使用方可为两个实例分别填pllA和pllB；库内仍使用pllCfg.Ts/Kp等字段，参数在实例Mask工作区解析。已有库默认只读，更新时先通过model_edit关闭库Lock，修改并检查后恢复Lock、保存；不会断开调用方库链接。[实例测试模型图](instances_diagram.png)和[隔离分析](../waveform_analysis/INSTANCES.md)记录实际验证。

采样周期默认 50 µs，固定步长离散求解器。输入须有限；NaN/Inf 不属于本版的运行输入契约，验证脚本在仿真前检查输入。
