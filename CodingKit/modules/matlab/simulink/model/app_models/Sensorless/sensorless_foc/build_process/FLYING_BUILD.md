# 带速捕获模型搭建过程

[FlyingFluxFOC](../src/FlyingFluxFOC.slx)是本模块新增的直接运行App。[build_flying_foc.m](build_flying_foc.m)使用`model_edit`创建结构；旧三份启动App及共享库不作结构修改。

1. 复用`PMSMBridgePlant/BridgeMotor`，以SPMSM的Ld=Lq和非零初始转速运行。桥模式0表示所有受控开关关断，仍保留二极管，不向电机施加0V短路，不清零物理电流或转速。
2. 接`CurrentSample`取得当前αβ电流；桥电压先过5 μs的`VoltageCompleted`，再以50 μs采样。这样估算器只取得已经完成的物理区间电压。采样时间定义见[参数页](../parameter/FLYING_PARAMETERS.md)。
3. 直接链接`FluxObserver/Flux`。该库由电压/电流估计磁链、角度、带符号速度和valid，不需要Plant方向。真实角/速度只送记录和Scope。电压测量在本MIL中理想、无偏置；它不是仅从占空比重建的关断电压。
4. `AgeAlign`用估算ω及2.5 μs名义年龄作局部相位推进。用`ClarkePark/Park`将采样电流和已推进的端电压变到当前控制坐标。
5. `Sequence`只接测量dq电流、估算速度/质量、端电压模及命令。持续资格25 ms后，核对方向、捕获电流和调制电压余量，再进入10 ms的PI准备状态；准备期间条件变化也会拒绝接通。
6. 准备阶段令参考电流等于当前测量电流，使误差为0；`flying_pi_residual`让电流PI积分跟踪测得反电势。速度积分同时取消比例项。此时桥仍关断，跟踪是控制状态准备，不是“关断电压可由PWM执行”的假设。
7. 准备完成后才给桥模式1。使用同一个估算坐标，电流给定从原测量值以100 A/s逐步变化；速度PI分配iq，id回到0。`CurrentControl/FrameTrackingPI`、`VoltageLimit`、逆Park和`Inverter/SVPWM`继续共用。该App没有额外角坐标切换，FrameTrackingPI的额外旋转/track端口为0。
8. 正常运行以最终电压圆限幅差作抗饱和残差；失锁、方向不符或电流过大后进入锁定退出。状态转移在下一50 μs拍生效。reset/disable只复位控制/估算状态，不接Plant复位。
9. 保存三组日志、七组Scope并跑正常、拒绝、失效和步长工况；独立读取库链接、端口源、嵌入源码及Scope顺序，见[验证记录](../waveform_analysis/flying_verification.json)。

初次编译暴露了闭环继承尺寸不足，正式构建器已为Controller输入及三相占空比输出显式写入维数/数据类型。运行器把Simulink的列向量日志整理成时间×通道；不靠变更物理方程绕过编译。

三个App自有算法M位于`src/`，由构建器嵌入MATLAB Function；修改这些算法需要在隔离目录重建并验证。参数默认值从本模块M重载，不需要重建模型。构建器拒绝覆盖已有SLX。

本版负责已有转动的同向接管。静止转子、要求反向或电压过高时明确拒绝；静止启动仍由原I-f或HFI App承担。未将它们临时串成未经验证的自动降级流程。

[运行](FLYING_USAGE.md) · [参数与Scope](../parameter/FLYING_PARAMETERS.md) · [推导](../docs/公式推导.md)
