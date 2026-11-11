# 基础 SMO 验证记录

- 模型文件：src/SlidingModeObserverTest.slx
- 参数文件：parameter/smo_parameters.m、parameter/refresh_smo_parameters.m；PLL引用angle_tracking参数
- 采样周期：50 µs
- 求解器/步长：FixedStepDiscrete / 50 µs
- 工况：±200、±600电角rad/s、加速、测量噪声、Rs失配、关闭补偿、复位、禁能、无效方向、经零反转、零速及低反电势
- 数据文件：`results.mat`（运行验证后生成）、[waveform_analysis/metrics.json](metrics.json)

MATLAB：26.2.0.3433840 (R2026b) Update 1。14/14项MIL通过，结构检查healthy。测试对象为Ld=Lq=1 mH、Rs=0.5 Ω、Flux=0.035 Wb的合成SPMSM，Iq=2 A；连续物理方程独立生成样本，θ/omega真值不进入观测器。窗口为0.25–0.30 s。

| 工况 | 角度RMS / rad | 速度RMS / 电角rad/s | 有效比例 | 结果 |
|---|---|---|---|---|
| positive | 0.007356 | 1.157e-11 | 1 | 通过 |
| negative | 0.005923 | 1.164e-11 | 1 | 通过 |
| high_positive | 0.02063 | 7.993e-11 | 1 | 通过 |
| high_negative | 0.01921 | 8.004e-11 | 1 | 通过 |
| acceleration | 0.01731 | 0.0001185 | 1 | 通过 |
| measurement_noise | 0.007219 | 3.192 | 1 | 通过 |
| rs_mismatch | 0.007520 | 1.160e-11 | 1 | 通过 |
| without_compensation | 0.06551 | 1.163e-11 | 1 | 通过 |
| reset | 0.007356 | 8.402e-7 | 1 | 通过 |
| disable | 0.007356 | 8.179e-7 | 1 | 通过 |
| direction_invalid | 1.912 | 200.0 | 0 | 通过 |
| reversal | 0.009243 | 0.0003555 | 1 | 通过 |
| zero_speed | 0.9639 | 0.000 | 0 | 通过 |
| low_emf | 2.291 | 5.000 | 0 | 通过 |

正常工况角误差最大值<0.08 rad、速度RMS<15电角rad/s、有效比例>95%；未补偿对照角误差最大值<0.15 rad。门限仅用于本合成测试，不能外推为全电机性能。direction_invalid/zero_speed/low_emf按valid=0验收，大角度误差不表示可用估算。零速/5 rad/s工况仍提供direction=+1，验证失效来自观测能力资格，而非简单缺少方向输入。

200电角rad/s时，开启LPF补偿的角度RMS为0.007356 rad（约0.421°），关闭为0.06551 rad（约3.754°）。补偿仅处理离散LPF稳态相移，电流观测边界层、采样保持及动态延迟仍有残差；600 rad/s时残差更大，不能靠常数偏置掩盖。

边界层通过电流估计误差产生等效注入，所以i_hat与真实电流存在有界差异；[CurrentScope对应图](tracking.png)不要求两条曲线逐点重合。噪声种子23，电压/电流标准差0.02 V/0.01 A。Rs失配只增大观测器电阻20%，真实电机参数不变。

[反转图](reversal.png)中方向由测试工况已知设定；接近零速direction=0并重置，之后重新捕获。可见valid失效与再资格过程，未证明自动辨向、带载过零或闭环无扰切换。valid不能单独作为整机接管条件，后续还需启动/切换监督。

未进行Sensor App并行对照、真实逆变器/采样链验证、single/SIL/C2000构建或板测。完整产品安装仍在进行，安装结束后另做环境回归；本页是已完成的独立MIL记录。
