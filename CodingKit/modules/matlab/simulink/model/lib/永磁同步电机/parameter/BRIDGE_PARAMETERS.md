# 桥与线性 PMSM 耦合对象：参数、信号与 Scope

## 配置参数

[pmsm_bridge_parameters.m](pmsm_bridge_parameters.m)组合原电机与逆变器的名义值；[bridge_test_parameters.m](bridge_test_parameters.m)返回默认验证实例p。数值不是P650或自制板的辨识结果。参数均转为double，初值必须为实数有限标量；[refresh_pmsm_bridge_parameters.m](refresh_pmsm_bridge_parameters.m)刷新Vector与State0。

| 名称 | 默认值 | 单位 | 含义 / 来源 |
|---|---|---|---|
| Rs / Ld / Lq / Flux | .5 / .001 / .0012 / .035 | Ω / H / H / Wb | 每相电阻、线性dq电感及永磁磁链；继承pmsm_parameters |
| PolePairs / J / B | 4 / .0005 / .0001 | 1 / kg·m² / N·m·s/rad | 极对数、单惯量、黏性阻尼；同上 |
| Id0 / Iq0 / Speed0 / Position0 | 0 / 0 / 0 / 0 | A / A / 机械rad/s / 机械rad | 库的初值；验证实例另设Speed0=80、Position0=.1 |
| Ts | 5e-6 | s | 对象步长，测试求解器同周期 |
| Vdc | 48 | V | 理想刚性直流母线，继承inverter_parameters |
| DiodeVf / DiodeRon | .7 / .01 | V / Ω | 示例PWL二极管压降与导通电阻，反向漏电取0 |
| MechanicalEnabled | 1 | 0/1 | 1自由机械运动；0保持给定转速但位置继续转动，外部轴源补充机械功 |
| CurrentTolerance / VoltageTolerance | 1e-9 / 1e-8 | A / V | 二极管状态判定的double数值容差 |
| MaxCurrent / MaxSpeed / MaxAngleStep | 200 / 1000 / .1 | A / 机械rad/s / 电角rad每步 | αβ电流分量、转速及角增量的数值适用范围；不是硬件保护阈值 |
| bridgeTestCfg.Duration | .06 | s | 默认验证时长 |
| bridgeTestCfg.ModeTimes / ModeValues | [0,.015,.025] / [0,2,0] | s / 状态 | 滑行→主动短路→释放，事件必须对齐Ts |
| bridgeTestCfg.Duty / LoadTorque | [.5,.5,.5] / 0 | 1 / N·m | 三相占空比及有符号负载 |

Vector按`[Ts;Rs;Ld;Lq;Flux;PolePairs;J;B;Vdc;DiodeVf;DiodeRon;MechanicalEnabled;CurrentTolerance;VoltageTolerance;MaxCurrent;MaxSpeed;MaxAngleStep]`打包。State0由初始dq电流旋转得到αβ电流，并拼接机械速度/位置；两者是派生量，不手填。

## 输入信号

| 名称 | 单位 / 类型 | 来源 / 用途 |
|---|---|---|
| duty_abc | 1，double向量3 | mode=1时的理想平均PWM，占空比[0,1] |
| mode | double标量0/1/2 | 0全门极关断并保留二极管；1平均PWM；2主动短路 |
| load_torque | N·m，double标量 | 进入Te−Tl−Bω |

全门极关断不保证一直高阻：有存储电流或反电势超过母线时，二极管会导通。只有二极管也截止的子状态才是开路滑行。PWM [.5,.5,.5]是零线电压，仍与主动短路有相同的电流动态。

## 过程变量

| 名称 | 单位 / 初值 | 所在块 / 计算 |
|---|---|---|
| PhysicalState | [A,A,机械rad/s,机械rad]；cfg.State0 | UnitDelay，保存当前αβ电流、机械速度和展开位置 |
| L(theta)、oldFlux、matrix、forcing | H / Wb | Step，将书式(2.14)转换为静止坐标磁链平衡 |
| diodeStates | −1/0/+1 | Step隐式区间的上二极管/开路/下二极管状态；仅在mode=0解释 |
| neutralVoltage | V，无独立状态 | 浮动星点；全开路时选可行共模区间中点，不预测器件寄生共模 |
| nextPhaseCurrent | A，无独立状态 | 隐式方程的下一拍电流诊断，不用作测量反馈 |

Measure只读取当前状态，电流反馈无当前占空比直接馈通。Step的电压、二极管状态、母线电流和损耗属于区间[k,k+1]的等效量；不能当作已实现的瞬时ADC采样。后续App必须明确电压区间、采样时刻及年龄；本次尚未接入带速捕获App。

## 输出信号

库有16个输出，顺序见[bridge_trace_channels.m](bridge_trace_channels.m)。全部double，默认5μs。前两路current_ab/phase_current属于当前状态k，才是可用电流测量；next_phase_current只用于核对下一状态。bridge_loss只计关断二极管损耗，PWM/短路支路为理想器件；电机铜耗Rs·sum(iabc²)另行计算。

测试记录33列：1–3 dutyABC，4 mode，5负载；6–7 current_ab；8–10 phase_current；11–13 phase_voltage；14–15 voltage_ab；16机械速度；17电角包角；18转矩；19母线电流；20–22二极管状态；23磁储能；24动能；25二极管损耗；26电压方程残差；27–29下一拍相电流；30星点电压；31–33桥臂极点电压。返回结果r.columns登记实际列号。

母线电流正号表示DC向电机供能，负号表示回馈。电压是相对星点的三相等效端电压；pole_voltage相对DC负端。当前桥使用线性磁路，尚未接入高频饱和对象。

## Scope 通道

| Scope | 通道顺序（全部double） | 实际来源 | 观察内容 |
|---|---|---|---|
| PhaseCurrentScope | 1 ia、2 ib、3 ic，A | Plant.y2 | 当前状态的三相电流 |
| PhaseVoltageScope | 1 va、2 vb、3 vc，V | Plant.y3 | 区间等效端电压，含关断续流钳位 |
| MechanicalSpeedScope | 1 ωm，机械rad/s | Plant.y5 | 滑行与制动的速度差别 |
| EnergyScope | 1磁储能、2动能，J | Plant.y10/y11 | 电磁和机械储能 |
| PowerScope | 1DC输入、2AC输入、3二极管损耗，W | Vdc·Plant.y8、dot(Plant.y3,Plant.y14)、Plant.y12 | 同一隐式区间的桥功率平衡，不包含电机铜耗 |
| BridgeModeScope | 1 mode、2 a/3 b/4 c二极管状态 | Inputs.y4、Plant.y9 | 门极状态与关断后的二极管导通 |
| EquationResidualScope | 1残差，V | Plant.y13 | 离散电压方程数值残差 |

[运行](../build_process/BRIDGE_USAGE.md) · [推导](../docs/公式推导.md)
