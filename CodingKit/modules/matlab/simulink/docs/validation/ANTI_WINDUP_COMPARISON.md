# 离散并联 PID 抗积分饱和对照

**结论**。当前离散并联 PID 的回算抗饱和已经实现了参考模型的同一机制。统一离散方法和有效回算系数后，四组工况的所有记录逐点相等。参考接法可作为回算原理示例，直接搬入当前库没有算法收益。

| 模型文件 | 参数文件 | 采样周期 | 求解器/步长 | 工况 | 数据文件 |
| --- | --- | --- | --- | --- | --- |
| DiscretePID/Controller；本地 antiwindup.slx、antiwindup_complete.slx | [库参数 M](../../model/lib/离散并联PID/parameter/discrete_pid_parameters.m) | 数值对照 1 ms | 对象 ZOH 精确离散，积分前向欧拉；原 demo 可变步长 | 正、负限幅退出，非对称换向，无饱和 | [指标](antiwindup_comparison.json)、[浏览 CSV](antiwindup_comparison.csv)、[原 demo 实跑](antiwindup_native.json) |

## 两种接法的关系

当前库用 $v=K_p e+x_i+x_d$ 计算限幅前请求，$u=\operatorname{clip}(v)$。前向欧拉的回算积分更新为

$$
x_i[k+1]=x_i[k]+T_s\left(K_i e[k]+K_{aw}(u[k]-v[k])\right).
$$

完整 demo 的 `Sum2` 得到 $v-u$，`Gain2=20` 后从误差减掉，再乘 `Gain=1400` 并积分。`Gain1=1` 位于 P、I 求和后，故 $v=K_p(e+z)$，$\dot z=1400\{e+20(u-v)\}$。换为输出量纲的积分状态 $x_i=K_p z$ 后，有效积分增益 $K_i=K_p\cdot1400$，有效回算增益 $K_{aw}=K_i\cdot20=28000\ \mathrm{s^{-1}}$。原 demo 使用连续积分。统一到离散库参数 $K_i=8$、$K_{aw}=20\ \mathrm{s^{-1}}$ 时，参考接法中乘残差的系数应为 $20/8=2.5$。

原始两个 demo 都实跑了 1 s。`antiwindup.slx` 的限幅块未接入对象，对象输入峰值约 6.105。`antiwindup_complete.slx` 的对象输入被限制为 ±2，请求峰值约 2.087。两者的执行器条件不同，因此使用下表的统一限幅对照判断抗饱和收益。

## 同限幅对照

对照取 $K_p=1.2$、$K_i=8$、$K_d=0$、$T_s=1$ ms、一阶对象 $\tau=0.08$ s。正向工况给定先为 2，到 0.5 s 改为 0.4，执行器为 ±1。恢复时间从 0.5 s 起算，进入并保持在绝对误差 0.02 以内。

| 接法 | 恢复时间 s | 释放后误差积分 | 积分绝对峰值 |
| --- | ---: | ---: | ---: |
| 现有库方程，Kaw=20 | 0.605 | 0.05345 | 0.3992 |
| demo 接法，换算为同一 Kaw | 0.605 | 0.05345 | 0.3992 |
| demo 的乘数 20 直接用于现有 Ki，有效 Kaw=160 | 0.747 | 0.08981 | 1.0860 |
| 无抗饱和 | 1.444 | 0.52674 | 4.6428 |

将原 demo 有效 $K_{aw}=28000$ 直接代入 1 ms 前向欧拉时，数值对照在 0.005 s 的下一状态超过 $10^6$ 阈值。固定饱和区、固定 $e$ 时，积分回算的离散极点是 $1-T_sK_{aw}$。1 ms 时为 −27，25 μs 时为 0.3，62.5 μs 时为 −0.75。后两者仅说明该局部递推的极点，整机增益仍需结合对象和执行链验证。

两种接线的运算量接近，均需一次限幅差和一次回算乘加。现有形式让 $K_i$ 与 $K_{aw}$ 独立整定，也可直接用执行端残差。demo 把回算系数与积分增益相乘，改 $K_i$ 时会同时改变回算速度。对电机电流环，更值得检查的是回算点能否取得**最终执行电压**的残差，尤其在 dq 电压圆限幅和母线下跌时。实验使用现有 PID 的方程做数值对照，原库 SLX 和测试台字节一致。

原始文件位于 `F:/Study/Motor Control/zhihu/积分抗饱和`。数值对照可运行 [compare_antiwindup.py](../scripts/compare_antiwindup.py)，输出到运行目录。回算与执行端跟踪见 [MathWorks 抗积分饱和示例](https://www.mathworks.com/help/simulink/slref/anti-windup-control-using-a-pid-controller.html)。
