# 公式、状态与边界

## 坐标和责任

采用幅值不变变换、相峰值电流、d轴沿永磁磁链；p为极对数，ωe=p·ωm为带符号电角速度。常参数模型为：

```text
Te = 1.5*p*[Flux + (Ld-Lq)*id]*iq
vd = Rs*id - we*Lq*iq
vq = Rs*iq + we*(Flux + Ld*id)
```

分配器用稳态电压关系判定参考可行性；整机电气对象仍保留 L·di/dt，电流 PI 和最终电压限制负责动态控制。不能用这里的预测电压替代实际电压反馈。公式依据见[参考资料](../ref/README.md)。

## MTPA：按电流幅值生成表，再按转矩查询

令 Δ=Lq−Ld≥0，对每个电流幅值 I 生成：

```text
id = -2*Δ*I² / [Flux + sqrt(Flux² + 8*Δ²*I²)]
id = max(id, IdMin)
iq = sqrt(max(0,I²-id²))
T  = 1.5*p*(Flux-Δ*id)*iq
```

这是避免小凸极性时两大数相减的写法。Δ=0时自然得到id=0；禁止将Lq<Ld静默套入本实现。若负id边界先到，表在该边界继续分配iq。

初始化在0到CurrentMax生成257点，检查T严格递增。运行时abs(Trequest)夹到MaxTorque，查1D表得到id_mtpa，再按转矩公式重算带符号iq_mtpa。电压不受限时，它给出常参数模型下的最小电流候选；通过独立标量数值优化核对。表插值引入有限离散误差，不等于非线性磁链图的最优解。

## 弱磁：电压需求、滤波、积分和复位

可用电压考虑现有duty边界与预留：

```text
Uavail  = max(0,Vdc*VoltageReserve*(1-2*MinDuty)/sqrt(3))
Utarget = max(0,Uavail-FwVoltageMargin)   % 默认再留0.2V调节裕量
Ueff    = max(Uprev, Umodel)
Uf[k]   = alpha*Uf[k-1] + (1-alpha)*Ueff[k]
eU[k]   = Utarget[k] - Uf[k]
dx      = clamp(FwKi*FwTs*eU, -IdSlew*FwTs, +IdSlew*FwTs)
x[k+1]  = clamp(x[k]+dx, IdMin, 0)
id_fw[k]= x[k]
```

FwTs=1ms，alpha=FilterTau/(FilterTau+FwTs)=0.75，状态初值均0。id_fw先输出当前状态，再更新下一状态，因而没有同拍积分代数环。电压不足使eU为负，id_fw逐渐变负；电压充裕时回到0。每拍状态增量最多0.2A，IdMin阻止继续积分到更负处。

Uprev是上一完整电流拍、最终限幅前PI+FF模长。Umodel是请求转矩在当前选定id下、先做电流圆限制但尚未做电压限制时的稳态需求。仅用Uprev时，电压投影会先降低iq，电压需求降到边界，弱磁可能不进入；加入Umodel可保留未满足转矩所需的电压信息。两者取最大，仍保留实际电压反馈分支。Umodel不是Plant真值，使用的是输入速度与声明的电机参数。

Utarget比约束边界低0.2V，避免零转矩/无电压余量时积分器只渐近贴边。VoltageReserve是相对逆变器线性半径的预留，两者作用不同；调参时均可修改。

enable=0、reset=1或FwEnable=0时，滤波/积分的下一状态及对外诊断输出清零。复位优先；Allocator的电流输出也在控制禁能/复位时归零。这是控制器语义，不能等同硬件门极停机。

## 统一电流分配与可行性

取id_candidate=min(id_mtpa,id_fw)，夹到[IdMin,0]。在固定id下，电流圆给出 |iq|≤sqrt(CurrentMax²−id²)。再与请求转矩方向相交：正转矩只允许iq≥0，负转矩只允许iq≤0，零转矩只允许iq=0；分配器不会为满足电压约束擅自施加反向转矩。

含Rs的电压条件写为 a·iq²+b·iq+c≤0：

```text
a = (we*Lq)² + Rs²
b = 2*Rs*we*[Flux+(Ld-Lq)*id]
c = (Rs*id)² + [we*(Flux+Ld*id)]² - Uavail²
D = b²-4*a*c
iq_low/high = (-b ∓ sqrt(max(D,0)))/(2*a)
```

a>0由Rs>0保证。D≥0且电压区间与电流/方向区间有交集才置feasible=true；将请求iq夹到交集。使用带符号we，保留电阻交叉项，因此电动和回馈的边界不同，不能简单把速度取绝对值。

若交集为空，输出iq=0，保留已受限的负id帮助弱磁继续进入，并置feasible=false。这时预测电压可以超过Uavail；只有feasible=true的点才检查电压约束。发布：

```text
Tallocated = 1.5*p*[Flux+(Ld-Lq)*id_ref]*iq_ref
Tresidual  = Tallocated-Trequest
Imargin    = CurrentMax-hypot(id_ref,iq_ref)
Vmargin    = Uavail-Upredicted
```

allocated_torque是这对参考电流的转矩，不是实测转矩，也不是搜索所有id后的全局最大转矩。CurrentMax限制的是参考向量；电机瞬态电流仍需另行评估。

## 转矩速度PI与多速率

新TorqueStage中速度误差eω驱动：

```text
Trequest = SpeedKp*eω + xi
xi[k+1]  = xi[k] + SpeedTs*(SpeedKi*eω + SpeedKaw*Tresidual)
```

xi初值0，控制禁能/复位清零。Tresidual经Rate Transition进入1ms外环，避免将延迟的实测电磁转矩误作同评价点的限幅残差。默认SpeedKp=0.0179、SpeedKi=0.2、SpeedKaw=20。

原位置P/限速/斜率继续复用。mode=0为直接转矩请求，mode=1为速度，mode=2为位置；本批整机验证使用速度模式。100µs分配和电流拍、1ms弱磁及外环、5µs对象积分分别记录；插入Rate Transition不证明真实C2000 ISR调度或最坏执行时间。

当前完成double MIL。非线性磁链、MTPV、动态参数估计、single/C生成/SIL/PIL及真实退磁边界不在本次验证范围。
