# SMO在Sensor整机中的并行对照

- 模型文件：src/SensorObserverCompare.slx，通过库链接复用SlidingModeObserver/SMO及其PLL。
- 参数文件：parameter/observer_compare_parameters.m；每例完整参数快照在results.mat。
- 采样周期：控制、SMO、PLL、日志均50µs；速度环1ms。
- 求解器/步长：固定步长ode4 / experimentCfg.Step=5µs。
- 工况：以下8项，默认0.8s；强制转速案例0.4s。
- 数据文件：waveform_analysis/results.mat、waveform_analysis/metrics.json；positive、negative、two_feedback_ticks的PNG/SVG位于同目录。

R2026b Update 1下8/8通过。ObserverMonitor及根层连接检查均为healthy；监测子系统无Outport，控制持续使用位置反馈。实际硬件未接入。

## 稳态估算与失效预期

指标窗口为每例最后0.2s，包含窗口全部样本，不按valid筛选后再计算。普通运行检查角RMS<0.1rad、速度RMS<8电角rad/s、valid比例>0.95；禁能/复位案例则要求所有估算器输出为0且valid=0。

| 工况 | 角度RMS rad | 速度RMS 电角rad/s | valid比例 | 检查结果 |
|---|---|---|---|---|
| positive | 0.001367955 | 0.00244154 | 1 | 实际机械速度环+0.1N·m负载 |
| negative | 0.001367955 | 0.00244154 | 1 | 负速度给定与负方向负载，Direction=-1 |
| no_feedback_delay | 0.001367864 | 0.00243919 | 1 | 0拍反馈年龄 |
| two_feedback_ticks | 0.001368045 | 0.00244387 | 1 | 2拍反馈年龄，电压与参考共同对齐 |
| rs_plus_20_percent | 0.001363984 | 0.00244087 | 1 | 仅观测器Rs增加20%，Plant不改 |
| disabled_observer | 1.81167 | 159.885 | 0 | 预期不估算；输出0，Sensor控制继续运行 |
| reset_observer | 1.81167 | 159.885 | 0 | 持续复位，预期不估算；输出0 |
| imposed_rotation | 0.001618865 | 2.88e-12 | 1 | 200电角rad/s强制转速，与原独立夹具对照 |

禁能/复位时较大的角/速度误差是预期结果，该案例未声称估算收敛。Rs偏差这一例不能代表完整参数敏感性评估，也不据此比较不同观测器优劣。

## 年龄与不干预控制的核对

验证脚本用原52列trace中40:42的Plant相电流、43:45的实际端电压独立计算Clarke，再按FeedbackTicks对齐。28列观测记录中的i、u、参考角/速度必须逐样本对应同一过去时刻。8例最大年龄关系误差：角度4.44e-16rad、电压1.78e-15V、电流4.44e-16A；速度关系也在1e-9rad/s容差内。SMO输出与同年龄参考比较，未把延迟误当成算法相位误差。

改变观测器Rs、禁能观测器或持续复位时，原52列控制trace相对positive案例的最大差均为0。此比较和监测子系统无输出端口共同证明本轮观测分支没有接管控制。库中观测器的7个输入没有Plant真值角度/速度；Direction是工况配置。

默认平均逆变器、死区关闭，实际相电压在控制间隔保持。本结果没有覆盖真实PWM电压积分、异步ADC、多传感器独立延迟或执行中高频注入。

## 波形解释

[positive.png](positive.png)显示0.05s给定后机械加速、观测器获得有效性及0.35s负载变化。开始阶段角误差较大且valid=0，不能只看最终重叠的速度曲线。[negative.png](negative.png)用于核对有符号估算速度和负方向条件；[two_feedback_ticks.png](two_feedback_ticks.png)的参考与作用电压共同多延迟一拍，稳态误差没有按当前Plant角度错误计算。

CurrentScope显示估计电流与测量电流，SMO的边界层稳态残差并不要求严格为0。角度已包到[-π,π]，过边界的显示跳变不等于物理角跳变，应看包角误差列24。

下一步是Sensorless App的I-f起转、持续捕获和电流/PI状态转换。这个Sensor对照的成功不替代无位置启动、接管、失锁退出或目标代码验证。

[模块入口](../README.md) · [运行方法](../build_process/USAGE.md) · [Scope与列序](../parameter/README.md)
