# 磁链观测器的搭建与各部分作用

理论位置见[书籍核对](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md)：2.2.1给出SPMSM磁链，3.2讨论初值、漂移与滤波。本模型采用同一物理基础，离散频率补偿由本工程推导，未声称逐块复刻书中图3.4。

## 1. 从电压到定子磁链

SPMSM满足 `dψs/dt=uαβ−Rs·iαβ`、`ψrotor=ψs−L·iαβ`。ψrotor方向就是转子电角度；前提是Ld=Lq=L。IPMSM的有效磁链需使用Lq，且幅值随id变化，当前块不承担该实现。

`FluxObserver/Flux`有六个输入端口和十四个输出端口；`VoltageAB`、`CurrentAB`先组成两个二维向量。`Active=enable AND NOT reset`统一控制状态更新。Mask分别接收本实例的`cfg`与`trackerCfg`，因此App可以给不同实例传入不同参数结构体。

## 2. 泄漏积分与直流去除

`FluxStates`是四维Unit Delay，初值全零。`Predict`执行[flux_predict.m](../src/flux_predict.m)：

```text
z[k+1]  = a·z[k] + b·(u[k]−Rs·i[k])
dc[k+1] = d·dc[k] + (1−d)·z[k]
filtered[k] = z[k]−dc[k]
```

其中a=exp(−2π·LeakHz·Ts)，b=(1−a)/(2π·LeakHz)，d=exp(−2π·DcHz·Ts)。关闭泄漏后a=1、b=Ts；关闭直流去除后d=1，dc始终保持零。系数由[refresh_flux_parameters.m](../parameter/refresh_flux_parameters.m)计算，使用expm1避免小步长相减损失。

泄漏积分使恒定误差不再形成无界斜坡，但仍会留下有限直流偏移。dc状态再估计并去除该偏移。未知真实初始磁链没有注入状态；模型依靠稳定滤波的暂态消退重新取得旋转磁链。它不能靠这一过程识别静止位置。

## 3. 为什么还要频率补偿

泄漏与直流去除都会改变旋转磁链的幅值、相位。对固定电角速度ω，令q=exp(jωTs)，以上离散系统相对理想正弦磁链的传递关系为：

```text
H = j·ω·b·(q−1) / ((q−a)·(q−d))
Craw = 1/H
```

`Compute`执行[flux_compute.m](../src/flux_compute.m)。复数C作用到αβ向量，等价于`Re(C)·filtered + Im(C)·J·filtered`，其中J·[α;β]=[−β;α]。补偿后得到ψs，再减L·i得到ψrotor。

低频直接求1/H会放大噪声，因此20–100电角rad/s渐入补偿，最大增益限制为4。`compensation_ready`只在补偿权重至少0.99且未触及增益限幅时为1；本例有效速度门限另为120电角rad/s。这些是本机参数，不是全电机适用范围。

补偿频率来自`FrequencyState`保存的上一拍估算速度低通值。它以PLL速度经5 Hz低通更新；当前PLL输出不直接反馈到本拍相位计算，避免代数环及瞬时补偿耦合。恒频补偿不能消除加速时的全部动态误差，相关结果单独记录。

## 4. 相位、转矩和有效性

`Phase`执行atan2(ψrotor_beta,ψrotor_alpha)，共用库[AngleTracking/PLL](../../../相位跟踪/README.md)跟踪该相位。转矩为`1.5·PolePairs·cross(ψrotor,i)`。等效残差为`abs(norm(ψrotor)−Flux)/L`，单位是等效A；它只检查磁链幅值一致性，并不是测量电流减预测电流。

valid同时要求：Active、PLL已连续锁定、速度幅值达门限、磁链幅值不过大、等效残差不过大及补偿已就绪。PLL内部还检查最小磁链幅值。真实角度误差不参与上述条件。

## 5. 时序与复位

输出使用已保存的磁链状态x[k]；u[k]对应[kTs,(k+1)Ts)执行区间，用于x[k+1]，不存在电压到本拍角度的直接通道。电流i[k]用于本拍减L·i及下一拍积分。

reset=1或enable=0时，Compute的磁链/转矩/残差/ready输出置零，PLL退出资格，下一拍四个磁链状态与频率状态清零。`filtered_speed`是状态诊断，禁能/复位触发当拍可保留上一拍值，下一拍为零；验证脚本按这一时序检查，而非误写所有输出同时清零。

## 6. 测试台与保存

[build_flux_observer.m](build_flux_observer.m)通过model_edit创建结构、参数和连接；两个MATLAB Function块通过公开MATLABFunctionConfiguration写入本目录源码。候选模型先在隔离目录完成24项MIL，之后按SHA256核对迁入src，并在正式路径重新加载、检查连接、核对内嵌Compute源码及默认仿真。

测试台从独立dq轨迹计算电压/电流，真实θ/ω仅接Scope和误差记录。fixture的direction列只记录、不接本模块。七组Scope和24列日志见[参数页](../parameter/README.md)，运行步骤见[USAGE.md](USAGE.md)。

[测试台图](test_diagram.png) · [结果](../waveform_analysis/ANALYSIS.md) · [模块入口](../README.md)
