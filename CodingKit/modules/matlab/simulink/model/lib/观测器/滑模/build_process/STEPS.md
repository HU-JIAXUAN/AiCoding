# SMO 搭建过程与各部分作用

1. 把 αβ 电压/电流各组成二元素向量，Unit Delay 保存当前预测电流 i_hat[k]。
2. 误差为 i_hat[k]−i[k]。除以 Boundary（A）后逐轴限幅到 [-1,1]，再乘 SlidingGain（V），得到滑模注入 z[k]。用连续边界层降低硬 sign 的抖振。
3. 精确离散 R-L 预测：A=exp(−Rs×Ts/L)，B=(1−A)/Rs，i_hat[k+1]=A×i_hat[k]+B×(u[k]−z[k])。这是把该周期电压和注入视作常值的离散模型。
4. 注入经 e_hat[k+1]=a×e_hat[k]+(1−a)×z[k] 低通，a=exp(−2π×FilterHz×Ts)。EMF 状态有一拍状态更新关系，不能忽略其相位延迟。
5. 方向已知为 s 时，phase_raw=atan2(−s×e_alpha,s×e_beta)。反转必须处理 s，否则相位会偏 π；低速/方向未知时由调用方给 direction=0。
6. 使用上一拍估算电角速度计算离散 LPF 的稳态补偿：phi=atan2(sin(omega_prev×Ts),cos(omega_prev×Ts)−a)。测量相位为 wrap(phase_raw+Compensate×phi)。上一拍速度打断代数环；补偿只针对这一级 LPF 的稳态相移，不消除全部模型或数字延迟。
7. 同一个 AngleTracking/PLL 库块输入补偿相位和 EMF 幅值，输出角度/速度。SMO valid 还要求方向有效且 |omega_e_hat|≥MinOmega。
8. reset、禁能、direction 非 ±1，或方向发生变化时重置/禁用内部状态，valid=0；方向变化当拍先复位，再从下一拍重新估算。过零由启动/切换流程接管，不能以此测试宣称完整反转控制已完成。
9. 测试台输入来自连续SPMSM方程：iα=−Iq sinθ，iβ=Iq cosθ，e=omega×Flux×[-sinθ,cosθ]，u=Rs×i+L×di/dt+e。真值θ/omega只送Scope和记录，不送SMO。电压按每个区间起点采样并零阶保持，离散化差异保留在误差中。From Workspace设置Interpolate=off、OutputAfterFinalValue=Holding final value，时间轴覆盖StopTime。

时刻约定：i_hat[k] 与 i[k] 同时比较；u[k] 表示区间 [kTs,(k+1)Ts) 的实际作用电压，用于生成下一拍电流状态。接入真实执行链时，应按采样和执行时刻对齐，不能直接接限幅前 PI 请求。

BoundaryPole=A−B×SlidingGain/Boundary 是边界层内线性误差极点。默认约 −0.506，更新参数时检查其在单位圆内；该检查不等于全域非线性稳定证明。

本实现是可读的基础边界层 SMO；与官方当前 Sliding Mode Observer 的离散扰动观测实现不同，尚未完成逐点官方块对照。
