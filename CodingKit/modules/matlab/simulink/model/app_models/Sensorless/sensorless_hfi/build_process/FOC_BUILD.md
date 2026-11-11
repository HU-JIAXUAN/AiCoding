# HFI位置启动后接入电流与速度闭环

模型为`src/SensorlessHFIFOC.slx`，搭建入口[build_hfi_foc.m](build_hfi_foc.m)。原SensorlessHFIStartup保留，便于单独学习探针、轴线与极性；新模型通过库链接组合这些算法和控制器。

1. **Position**：正交探针→一拍快照→实测逆电感均值/HFI轴线→双脉冲极性→完整位置资格。探针完成后停算，不重复拟合；算法仍属于observer_hfi库。
2. **Measurement**：物理αβ电流经InverseClarke、三相ADC、Clarke和可选年龄延迟进入估算与控制。真实θ只进入误差/Scope；Park使用完整估算角度。
3. **Controller**：速度模式使用共用TorquePI，转矩模式直接选给定；转矩除Kt并限q电流，id参考0。FrameTrackingPI以50 μs计算电压，保留额外坐标修正时的状态转换；dq前馈实际加入前受控制使能门控。
4. **速度给定与外环时序**：共用MotionControl/SpeedProfile在未取得位置时清状态，控制接通后按每拍允许增量爬升。TorquePI的误差、回算、使能和复位都先以1 ms采样；验证另外检查积分真正更新的时间网格。仅诊断支路用RateTransition统一记录为50 μs，控制支路不经这些日志块。
5. **VoltageStage**：基波电压转αβ，与HFI/探针/脉冲请求相加，再统一圆限幅、SVPWM及平均逆变器。观测器用执行增益和延迟后的实际电压，不能用PI限幅前请求替代。
6. **回算位置**：电流PI残差为同拍PWM指令空间中的可行电压减合成请求，再Park回当前估算坐标。执行增益损失属于对象偏差，由电流积分纠正；不把该比例损失或上一拍执行电压作为“当前命令不可行”的残差。
7. **Supervisor**：独立UnitDelay保存everAcquired、lossSamples、faultCode。测量非有限/电流模过限锁存故障1；已有完整位置后连续失效2 ms锁存故障2。控制还立即受position_valid门控，锁存故障进一步关闭全部注入/控制请求，需外部禁能或复位清除。

物理对象使用真实电压驱动的非线性凸极/饱和PMSM，J/B保持原值。0 V平均电压对应本模型的电气连接，不等于实际高阻断开；例如外部恒负载仍能带动电机产生短路制动电流。此次不是PWM器件开关或硬件故障关断验证。

## 从实际失败得到的两处修正

首次24项验证中，执行增益减半的电流dq误差约.7385 A；原因是把比例损失也回算掉，积分不能充分补足所需命令。改为只回算指令可行性残差后，该工况重新验收。

另一个失败是禁能后重启：旧RateLimiter在等待位置期间仍保留8 rad/s请求，约.866 s产生.665 A的q参考阶跃，随即扰动HFI锁定。改用带明确状态清除的共用SpeedProfile后，重新接通从0按40 rad/s²爬升。没有放宽原有误差、资格或失锁阈值。开发前后数据另存于waveform_analysis，最终24项全部重跑。

运行与临时改参方法见[FOC_USAGE](FOC_USAGE.md)，九组Scope、九份日志与各列单位见[FOC_PARAMETERS](../parameter/FOC_PARAMETERS.md)。高低速基波融合继续在本App扩展，当前位置/速度均来自HFI。
