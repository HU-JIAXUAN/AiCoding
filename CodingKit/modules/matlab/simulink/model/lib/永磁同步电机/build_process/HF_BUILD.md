# 高频注入与极性测试所用的物理PMSM

本实现供无位置观测器测试复用，保存在pmsm_plant模块。主要参考书第4.2节、印刷79–82页/PDF108–111页的磁链和增量电感关系，以及第8.2节、印刷203–204页/PDF232–233页的正负脉冲极性辨识。来源及各算法范围见[书籍核对](../../../../docs/references/BOOK_SENSORLESS_DESIGN.md)。

## 1. 为什么需要增量电感

高频电压引起的电流变化由磁链对电流的导数决定。为同时表示几何凸极及磁极方向造成的饱和差异，选用下列可读、可微的合成磁链关系：

```text
ψd = ψm + Ld0·[id−s·Is·log(cosh(id/Is))] + M·iq
ψq = Lq·iq + M·id

Ldd = ∂ψd/∂id = Ld0·[1−s·tanh(id/Is)]
Ldq = ∂ψd/∂iq = ∂ψq/∂id = M
Lqq = ∂ψq/∂iq = Lq
```

Ld0为id=0处增量d电感，s为饱和深度，Is为电流尺度，M为常量交叉电感。默认s=0.25：正id使Ldd降低，负id使Ldd升高。因此同幅值、同宽度的正负d轴电压脉冲可产生不同电流峰值。

这是本工程构造的示意性磁路，未拟合书中样机、有限元或实测数据。q轴电感和交叉电感仍为常量，没有完整损耗/温度/磁滞模型。它适合验证信号链、符号、增量电感与极性流程，不代表某台实际电机的辨识结果。

磁链Jacobian对称；参数入口要求`Ld0·(1−s)·Lq>M²`及0≤s<1，因此所有id下的增量电感矩阵均正定。运行时从真实磁链导数求解电流，不对电流导数另加人为增益。log(cosh)采用等价的稳定计算式，避免大电流时cosh溢出。

## 2. 四个物理状态与电压平衡

`PhysicalStates`为连续Integrator，保存[id,iq,ωm,θm]。输入只有uα、uβ和有符号负载转矩。真实转子角在对象内部用于Park/逆Park及磁路方向；观测器不得读取它。初始化来自[本模块参数](../parameter/pmsm_hf_parameters.m)。

电压方程为：

```text
vd = Rs·id + Ldd·did/dt + M·diq/dt − ωe·ψq
vq = Rs·iq + M·did/dt + Lq·diq/dt + ωe·ψd
```

`Dynamics`先把实际αβ电压旋转到物理dq坐标，再求解这个2×2方程。电流、转矩与机械运动使用同一磁链：

```text
Te = 1.5·p·(ψd·iq−ψq·id)
dωm/dt = (Te−Tl−B·ωm)/J
dθm/dt = ωm
ωe = p·ωm
```

输出的电角度包角到±π，内部机械位置连续展开。饱和深度为零、M为零时退化到常参数PMSM；Ld=Lq再去掉几何凸极性。

## 3. 锁轴和自由转动

MechanicalEnabled=1为正常物理机械运动；默认J=5e-4 kg·m²、B=1e-4 N·m·s/rad。MechanicalEnabled=0表示外部理想夹具锁轴，仅用于电感响应及解析解对照，初始速度必须为0。锁轴可以有电磁转矩，夹具承担反力矩；这种结果不能证明自由转动时没有位移。

测试分别保存锁轴、自由转动和外部负载工况。双脉冲测试首先确认物理响应有差异，完整HFI极性观测器还要验证采样、峰值检测、差异门限及实际位移。

## 4. 库、采样与测试台

[build_hf_pmsm_plant.m](build_hf_pmsm_plant.m)通过model_edit建立PMSMHighFrequencyPlant库和测试台；Dynamics内嵌[pmsm_hf_dynamics.m](../src/pmsm_hf_dynamics.m)，只将导数送积分器；Measurements内嵌[pmsm_hf_output.m](../src/pmsm_hf_output.m)，仅消费状态和设置，共用磁链方程但不接当前电压，避免HFI反馈形成虚假代数环。参数以Mask传入。源码存在时，构建器拒绝覆盖，需要在隔离副本重建。

测试台的电压来自50 μs零阶保持输入，连续Plant采用ode4和2.5 μs步长，输出再以50 μs采样后送入六组Scope与13列trace。电压激励的方向由测试参数给定。对象没有观测器；测试中的真实角度只用于坐标/解析对照，不能当成无位置估算。

默认输入包含0.020–0.021 s的+4 V和0.065–0.066 s的−4 V脉冲，方向为α轴。时间和幅值来自[hf_plant_test_parameters.m](../parameter/hf_plant_test_parameters.m)，不是书中样机的脉冲数值。

[参数与Scope](../parameter/HF_PARAMETERS.md) · [运行方法](HF_USAGE.md) · [模块入口](../README.md)
