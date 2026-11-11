# 参数与信号

## 配置参数

可执行入口：[emf_parameters.m](emf_parameters.m)、[emf_test_parameters.m](emf_test_parameters.m)。LinearEmfTest调用`emf_parameters('spmsm')`，EemfObserverTest调用`emf_parameters('ipmsm')`；初始化时将emfCfg、pllCfg、emfTestCfg和testStim写入各自模型工作区。模型块的两个Mask参数依次为观测器结构体和PLL结构体表达式。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e-6 | s | 离散周期 |
| Rs / Ld / Lq | 0.5 / 0.001 / 0.0012 | Ω / H / H | IPMSM模型；spmsm配置将Lq设为Ld |
| BandwidthHz | 300 | Hz | 站立模型连续重复极点的设计频率；不是已测带宽 |
| MinEmf / MinOmega / MaxResidual | 1 / 30 / 1.5 | V / 电角rad/s / A | 幅值、方向一致速度和电流残差有效性阈值 |
| Flux / PolePairs | 0.035 / 4 | Wb / 1 | 解析对象参数，不输入状态预测方程 |
| Duration / ElectricalSpeed / InitialAngle | 0.4 / 200 / 0.4 | s / 电角rad/s / rad | 默认解析轨迹 |
| Id / Iq / Enable / Reset / Direction | -2 / 2 / 1 / 0 / [] | A / A / 逻辑 / 逻辑 / ±1或空 | []按解析速度确定方向 |
| pllCfg | 见定义函数 | rad、rad/s及时间增益 | [angle_tracking_parameters.m](../../../相位跟踪/parameter/angle_tracking_parameters.m)；MinMagnitude设为emfCfg.MinEmf，Ts与观测器一致 |

## 输入信号

端口1–7依次为u_alpha、u_beta、i_alpha、i_beta、direction、enable、reset。前四个为αβ坐标的V/V/A/A，direction只能±1，enable/reset为逻辑兼容double。测试刺激第8、9列为真实包角(rad)和电角速度(rad/s)，仅接入误差和Scope，不进入观测器。刺激结构体time=[]，按emfCfg.Ts逐行采样，无额外时间列。

## 过程变量

四状态为[i_hat_alpha;i_hat_beta;e_hat_alpha;e_hat_beta]，初始全0，禁能或复位时下一状态全0。方向变化也触发一拍复位。预测器采用前向Euler；PLL输出的估算速度用于模型中J旋转项，不能使用对象真实速度。具体方程见[搭建记录](../build_process/README.md)。

| 量 | 单位 / 状态初值 | 作用 |
|---|---|---|
| State前2项 / 后2项 | A / V；均0 | 当前拍的电流与反电势估计 |
| Predict.next | A/A/V/V | 本拍电压、电流和估算速度计算的下一拍状态 |
| Residual / ResidualNorm | A | i_hat−i及其范数，参与有效性判断 |
| Phase / Magnitude | rad / V | atan2(-direction*e_alpha,direction*e_beta)及反电势范数 |
| Active / ResetAny | 逻辑 | enable、合法方向、显式复位和方向变化的组合 |
| l1 / l2 | 1/s / V/(A·s) | 根据wo和Ld计算的Luenberger创新增益 |
| DirectedSpeed | 电角rad/s | direction*omega_hat，错误方向时不能给valid |

## 输出信号

输出顺序为theta_e_hat、omega_e_hat、valid、emf_alpha、emf_beta、i_hat_alpha、i_hat_beta、residual_alpha、residual_beta、phase_measured、emf_magnitude、phase_error。残差为估算减测量电流。两个测试模型均保存22列double trace：

| trace列 | 名称 | 单位 / 来源 |
|---|---|---|
| 1–7 | 实际输入端口1–7 | V、V、A、A、±1、逻辑、逻辑 |
| 8 / 9 | theta_true / omega_true | 电角rad / rad/s，独立解析轨迹 |
| 10 / 11 / 12 | theta_e_hat / omega_e_hat / valid | 电角rad / rad/s / 0或1 |
| 13–14 / 15–16 / 17–18 | emf_ab / i_hat_ab / residual_ab | V / A / A |
| 19 / 20 / 21 | phase_measured / emf_magnitude / phase_error | rad / V / rad |
| 22 | wrapped_angle_error | rad，atan2(sin(theta_hat−theta_true),cos(...)) |

## Scope 通道

下列六组Scope在两个测试模型中均已创建，每个Scope只有一个向量输入，顺序按向量元素排列。

| Scope | 实际通道顺序 | 单位 / 观察内容 |
|---|---|---|
| AngleScope | 1 theta_true，2 theta_e_hat，3 wrapped_angle_error | rad；包角及收敛误差 |
| SpeedScope | 1 omega_true，2 omega_e_hat | 电角rad/s；机械速度需除PolePairs |
| EmfScope | 1 emf_alpha，2 emf_beta，3 emf_magnitude | V；估算幅值和相位 |
| CurrentScope | 1 i_alpha，2 i_hat_alpha，3 i_beta，4 i_hat_beta | A；电流状态收敛 |
| ResidualScope | 1 residual_alpha，2 residual_beta | A；估算减测量 |
| StatusScope | 1 direction，2 enable，3 reset，4 valid，5 phase_error | ±1、0/1、0/1、0/1、rad |

Scope与保存数据均为50 μs默认周期。真实角度和速度只属于测试台的通道8、9；valid不使用真实角误差。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d,L_q$ | cfg.Ld / cfg.Lq | H | 原表mH乘$10^{-3}$；非线性对象另区分增量电感 |
| $\psi_m$ | cfg.Flux | Wb | 直接使用；此字段在emf/smo独立夹具中的作用另按本页说明 |
| $P$ | cfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | AngleTracking/PLL输出1；pllCfg.Theta0给定初始状态 | 电角rad | 这里PLL的输入已构造成转子电相位 |
| $\hat\omega_r$ | AngleTracking/PLL输出2 | 电角rad/s | 机械rad/s乘P得到电角rad/s；估计机械速度为本输出除P |

### 本模块局部量

$\mathcal Q[x,y]^T=[-y,x]^T$是平面旋转算子，$J$保留转动惯量意义。BandwidthHz是观测电流/EMF内核的名义设计频率；相位PLL的NaturalFrequency另按Hz配置。
