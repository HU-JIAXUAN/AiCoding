# 模块接口约定

无位置传感器首批已实现[PLL接口](../../model/lib/相位跟踪/parameter/README.md)和[SMO接口](../../model/lib/观测器/滑模/parameter/README.md)，均为50µs标量端口、SI单位；SMO输入u_alpha/u_beta、i_alpha/i_beta、已知direction及enable/reset，输出电角度、电角速度、valid和诊断量。i_hat[k]与i[k]同拍比较，u[k]用于[kTs,(k+1)Ts)区间的下一状态预测。其余[计划接口](../plans/SENSORLESS_PLAN.md)待实现，未建立公共Bus；真值角度/速度只进独立测试台的监测和记录。

状态：标量/定长向量接口已随模型实现，具体定义见各模块parameter。以下具名帧是公共语义角色，不代表已有Simulink.Bus对象；当前没有建立公共Bus类型。

首个已实现的小积木是[离散 PID](../../model/lib/离散并联PID/README.md)：首版使用无量纲 double 数值端口，周期 Ts；enable/reset/saturated 为 boolean。其同步复位、禁能清积分和诊断输出以模块 README 为准。接入电流环时再确定 A/V 物理量及最终电压限制反馈。

已实现 [math 坐标变换](../../model/lib/math/README.md)：幅值不变，α 沿 a 轴，θ 从 α 指向 d，q=−α*sinθ+β*cosθ，角度单位 rad。Clarke 保留 zero=(a+b+c)/3，反 Clarke 接收该零序；四个变换为无状态同拍计算。具体端口、过程变量和 Scope 在模块 parameter 中维护。

## 1. 统一约定

- 机械位置 rad、机械速度 rad/s、转矩 N·m、电流 A、电压 V、时间 s；rpm/degree 只用于明确的输入/显示转换。
- 默认幅值不变 Clarke/Park、相峰值、d 轴对齐永磁磁链。相序、反馈方向与电角度零位只在一个明确的适配/标定位置处理。
- 机械位置可连续展开；Park 使用包角后的 `theta_e = wrap(polePairs*theta_m + theta_offset)`，机械/负载轴与减速比另外说明。
- 每个组件说明输入/输出类型、周期、数据年龄、使能、复位和失效行为；有状态算法规定初始值与下一状态更新。
- 平台更换不能改变物理接口单位。板级 ADC count、编码器 count 和 PWM count 在目标适配中转换。

## 2. 信号所有者

| 接口 | 信息 | 唯一生产者 |
|---|---|---|
| MotionCommand | 模式、使能、位置/速度/转矩请求 | 指令装配/监督组件 |
| SampleFrame | abc 电流、母线、反馈采样值、采样时刻与有效性 | 采样适配 |
| MotionFeedback | 机械位置/速度、电角/电速度、反馈年龄与有效性 | 反馈处理 |
| CurrentRequest | id/iq 给定、可达转矩、限制原因 | CurrentReference |
| VoltageRequest | vd/vq 请求、对应时刻 | CurrentControl |
| ActuationStatus | duty、同评价点的电压限制残差/估计、限制原因 | 调制/执行边界 |
| ComponentStatus | 组件自身的使能、故障、饱和与采样状态 | 各组件独自产生，由 Supervisor 汇总 |

abc 电流与变换后的 dq 电流分开维护，不能让 SensorAdapter 和电流环同时写同一 dq 反馈。Plant 真值与控制反馈分开，观测器不接真值输入。

## 3. 组件责任

位置环输出速度请求，速度环输出转矩请求；电流分配器统一处理 id=0、MTPA、弱磁与电流/电压约束，输出可达转矩。电流环输出电压请求，调制/执行边界输出最终 duty 与限制状态。

第15步已在[MTPA弱磁](../../model/lib/MTPA弱磁/README.md)实现转矩语义：TorquePI输出N·m，Allocator输入Trequest、带符号we、Vdc、上一拍PI+FF模长及enable/reset，统一输出id/iq、分配转矩、残差和限制状态。速度积分器接Tallocated−Trequest，经1msRate Transition回算。allocated_torque是所选电流参考对应的转矩，不是实测值或全局最大转矩；feasible=false时没有稳态电压可行保证。06–14的旧MotionControl/Speed和MotorExperiment保持iq（A）接口；旧52列与新74列记录分别说明。

PI、ADRC、MPC 可有不同内部状态与专用参数；公共责任保持一致。小积木用数值端口，较大组件按需要用 Bus，不先建立庞大万能总线。

## 4. 限制、复位与时间

当次 tick 锁存输入，用当前状态计算请求，叠加该求和点负责的前馈，施加最终限制，再计算一致残差并更新下一状态。回算不能把外部前馈当作 PI 独自产生的电压。

电流 PI 知道最终可实现电压，速度 PI 知道可达转矩，位置环知道最终速度限制。死区门极补偿、端电压和限制残差在同一评价点核对，正常补偿不应凭空触发抗饱和。

当前可执行路径：CurrentStage把PI与FF相加，VoltageStage由同拍最终命令duty重建端电压并扣除已注入的补偿，再返回一致残差。延迟后的旧duty只用于Plant执行，不直接混入当前回算。反馈帧共同采样/延迟后再Clarke/Park；多传感器独立年龄、真实多任务Rate Transition/锁存及C2000装载点仍需目标适配实现。Enable表示控制器使能，不等同门极关闭或完整停机监督。

复位/禁能/重新使能要可重复；运行时算法切换不是首版能力。跨速率规定保持、缓冲和同 tick 顺序，不能仅凭插入 Rate Transition 就推断真实 ISR 顺序。

## 5. 无位置启动与接管

[无感启动](../../model/lib/无感启动/README.md)输出软件电流矢量角、速度和虚拟d/q电流请求；ready只允许检查捕获，不代表转子实际已同步。mode=1是零电流捕获窗口，mode=4/5是I-f爬升/等待。实际端口与采样点时序见其[参数页](../../model/lib/无感启动/parameter/README.md)。

[无感切换](../../model/lib/无感切换/README.md)消费启动角/状态、估算角/速度、valid及A单位电流残差，输出theta_used、omega_base、omega_frame、beta和监督状态。omega_frame含坐标过渡修正，不作为机械速度；mode=4/acquired=1在上层延迟一拍后送Startup。普通捕获要求持续资格，零电流窗口才能绕过软件角/速度差；相位方向/极性由观测器负责。Scope和全部输入/输出见[参数页](../../model/lib/无感切换/parameter/README.md)。

短时失效的预测不产生新的观测有效性，持续失效锁存run=0。电流环已新增[FrameTrackingPI](../../model/lib/电流环/build_process/FRAME_TRACKING.md)，输入额外坐标修正、当前误差/FF及最终电压残差；保存I/E/P/FF，转换时保留新的物理误差比例响应，残差只更新下一拍。其10项独立测试通过。App仍需旋转电流参考并接入该块，证明真实电流/电压/转矩衔接；两模块独立时序测试不能代替该证明。两者无Plant真值输入，未新建公共Bus。

## 6. 变更规则

端口、单位、信号所有者或状态语义改变时，同步更新定义、消费者和相关检查；重大边界变化记录 ADR。具体增益变化用实验配置/结果记录，不重复创建接口权威。
