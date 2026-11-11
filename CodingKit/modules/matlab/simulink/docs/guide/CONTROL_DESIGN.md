# 控制设计约束

当前已有[离散 PID](../../model/lib/离散并联PID/README.md)、[电流双轴PI与电压圆限制](../../model/lib/电流环/README.md)、[速度/位置环](../../model/lib/运动环/README.md)、[dq前馈](../../model/lib/电压前馈/README.md)和[死区补偿](../../model/lib/死区补偿/README.md)，由[整机实验](../../model/app_models/Sensor/experiment/README.md)连接。旧PID默认是无量纲夹具；新电流与外环使用明确SI单位和各自的模块参数。

## 第一版控制结构
原MotorExperiment使用位置P -> iq型速度PI -> 电流d/q PI，前馈和死区可关作基线。第15步[MTPAFWMotor](../../model/lib/MTPA弱磁/README.md)改为位置P -> 转矩型速度PI -> MTPA/弱磁/约束分配 -> 电流PI，并将分配转矩残差回算外环。弱磁用上一拍限幅前PI+FF电压与受电流圆限制的模型需求的较大值，滤波后驱动有界负id积分器。完整公式、复位和固定id下的含Rs电压区间见[DESIGN](../../model/lib/MTPA弱磁/build_process/DESIGN.md)。参数来自教学夹具；未实现非线性磁链图或MTPV。

## 必须显式定义的细节
1. Park/Clarke 正负方向及比例系数（幅值不变或功率不变，只能统一采用一种）。
2. 电流与编码器采样时刻，ADC 数值的滤波/延迟及测量有效性。
3. 离散 PID 的积分更新形式，积分饱和策略与使能/复位行为。
4. 电压向量幅值边界及 DC 总线定义；明确 SVPWM 线性区的边界约定。
5. dq 电压前馈和交叉耦合补偿必须采用相同的符号约定与速度量。
6. 对位置/速度/电流环分别设参考输入限幅，并避免内外环相互冲突。
7. 模式切换必须定义输出连续性与控制器内部状态恢复；第一版只要求启停/复位行为可重复；按电流环、平均执行链、速度环、位置环逐步搭建。

## 常用电机关系（示意，须与坐标约定一致）
\[
v_d = R_s i_d + L_d \dot{i}_d - \omega_e L_q i_q
\]
\[
v_q = R_s i_q + L_q \dot{i}_q + \omega_e(L_d i_d + \psi_f)
\]
\[
T_e = \frac{3}{2} p[\psi_f i_q + (L_d-L_q)i_d i_q]
\]

## 带宽设计方法
以电流环最内、速度环次之、位置环最外进行级联设计；记录闭环带宽、相位裕度、延迟和采样频率的约束，**不预设固定 1:10 规则为绝对标准**。先对 F1 对象进行分析，再验证 F2 加入延迟后的裕度变化。

## 策略扩展
- `Impedance`: torque = Kp*(q_ref-q)+Kd*(dq_ref-dq)+torque_ff；关节/电机轴、减速比、效率需要显式转换。
- `MTPA`, `FieldWeakening`, `AntiWindup`, `Feedforward` 独立接口封装。
- 未来 MPC 需要考虑显式的估计状态和约束而非仅仅误差信号。
