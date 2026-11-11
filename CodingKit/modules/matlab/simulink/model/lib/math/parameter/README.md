# Math 参数、信号与 Scope

新增BlendDQ与FrameBlendTest的7输入/1输出、9列刺激、11列记录、参数及3组Scope见[FRAME_BLEND.md](FRAME_BLEND.md)。以下继续说明原四个变换及ClarkeParkTest。

核心固定系数在 [ClarkePark.slx](../src/ClarkePark.slx)；场景默认值在 [clarke_park_parameters.m](clarke_park_parameters.m)。本测试的被变换量为电流 A，所有端口与记录均为 double；将同一算法用于电压时，相关数值单位整体改为 V。

## 配置参数

| 名称 | 默认值 | 单位 | 使用位置与含义 |
|---|---|---|---|
| Ts | 0.0001 | s | 测试输入采样周期与 FixedStepDiscrete 步长，不是四个变换的算法增益 |
| Duration | 0.1 | s | 默认仿真时长；测试脚本逐工况覆盖 |
| Amplitude | 5 | A，峰值 | 初始化生成平衡三相量，不是 RMS |
| FrequencyHz | 50 | Hz，电频率 | 初始化使用的旋转频率；负值表示反向旋转 |
| InitialAngleRad | 0.3 | rad | 默认三相信号与角度的共同起点 |
| AngleOffsetRad | 0 | rad | θ 相对三相信号相位的额外偏差；正偏差产生负 q |
| UseIndependentInverse | 0 | 1 | 0：反变换接正向输出；1：接 ctStim 中独立的 d_cmd/q_cmd/zero_cmd |
| ZeroSequenceGain | 1 | 1 | 测试模型的零序传递增益；正常取 1，取 0 演示丢弃零序 |
| RandomSeed | 2026 | 1，整数 | 回归脚本的局部随机流，不改变 MATLAB 全局随机状态 |

固定系数：Clarke α 使用 (2a−b−c)/3，β 使用 (b−c)/√3，零序使用三相平均；反 Clarke 的两条投影增益为 −1/2 和 √3/2。它们不是可随意调节的增益。Park 及反 Park 的符号和系数见 [DESIGN.md](../build_process/DESIGN.md)。

Amplitude/FrequencyHz/InitialAngleRad/AngleOffsetRad 只在初始化生成默认输入时使用；之后改变这些字段要重新生成 ctStim。批量脚本可直接提供不同输入，每次实际输入均保存在 cases.<工况>.inputs，不能仅凭生成器默认字段推断全部工况。

## 输入信号

TestInputs 从模型工作区 ctStim 读取七元素向量，经 InputChannels 分为七路。ctStim 使用 time=[] 的结构，每 Ts 读取一行。

| 输入列 | 名称 | 单位 | 来源/去向与含义 |
|---|---|---|---|
| 1 | a | A | 三相 a 分量 → Clarke 输入 1 |
| 2 | b | A | 三相 b 分量 → Clarke 输入 2 |
| 3 | c | A | 三相 c 分量 → Clarke 输入 3 |
| 4 | theta_e | rad | 同时送入 Park 与 InversePark，必须是电角度而非机械角度或 degree |
| 5 | d_cmd | A | 独立反变换 d 命令，仅 UseIndependentInverse=1 时被选择 |
| 6 | q_cmd | A | 独立反变换 q 命令，仅 UseIndependentInverse=1 时被选择 |
| 7 | zero_cmd | A | 独立反变换零序命令，仅 UseIndependentInverse=1 时被选择 |

默认 phase=2π*FrequencyHz*t+InitialAngleRad，三相量为 Amplitude*cos(phase+[0,−2π/3,2π/3])，theta_e=phase+AngleOffsetRad；三条独立命令默认为 0。仅将模式改为 1 而未填写独立命令时，反变换输出为 0。

theta_e 的正方向为 α→β，θ=0 时 d 轴沿 α，q 轴领先 d 轴 π/2。核心直接计算 sin/cos，允许负角及超过 2π 的有限角度；机械角到电角的极对数/零位换算由后续角度模块负责。

## 过程变量

| 名称 | 单位 | 所在位置 | 含义/公式 |
|---|---|---|---|
| alpha | A | ClarkeUnderTest 输出 1 | 固定坐标的 α 分量，(2a−b−c)/3 |
| beta | A | ClarkeUnderTest 输出 2 | 固定坐标的 β 分量，(b−c)/√3 |
| zero | A | ClarkeUnderTest 输出 3 | 三相平均 (a+b+c)/3，不参与平面旋转 |
| sin_theta / cos_theta | 1 | Park、InversePark 内的 Sine/Cosine | θ 的正弦与余弦；两边分别计算，当前没有单独 Scope 通道 |
| alpha*cos、beta*sin 等四项 | A | Park 内 Product | d 的两个投影为正相加，q 的 α*sin 项取负 |
| d / q | A | ParkUnderTest 输出 1/2 | 旋转坐标分量；平衡同步输入应为 d=Amplitude、q≈0 |
| d_used / q_used | A | dSource / qSource | 按模式选择正向 d/q 或独立命令，实际送入反 Park |
| zero_used | A | ZeroSequenceTransfer | 选中的零序乘 ZeroSequenceGain，实际送入反 Clarke |
| alpha_recon / beta_recon | A | InverseParkUnderTest 输出 1/2 | 按相同 θ 将 d_used/q_used 转回固定坐标 |
| a_recon / b_recon / c_recon | A | InverseClarkeUnderTest 输出 | 由 αβ 和 zero_used 重建三相量 |
| error_a / error_b / error_c | A | ErrorA/B/C | 重建值减原始输入；完整往返模式用于检查重建误差 |

这里没有积分、滤波状态或初值，也没有使能/复位输入。TestInputs 有采样周期，四个变换继承其时序；模型没有插入 Unit Delay。正反变换必须使用同一时刻的角度与输入。

## 输出信号

| 子系统 | 输出端口顺序 | 单位 | 复用方式 |
|---|---|---|---|
| Clarke | 1 alpha、2 beta、3 zero | 与 abc 相同 | 电流/电压三相量转固定坐标 |
| Park | 1 d、2 q | 与 αβ 相同 | 采样量转入电流环使用的旋转坐标 |
| InversePark | 1 alpha、2 beta | 与 dq 相同 | dq 命令转固定坐标，可交给使用 αβ 接口的调制模块 |
| InverseClarke | 1 a、2 b、3 c | 与 αβ0 相同 | 需要 abc 给定或验证重建时使用；零序为零时生成零和三相量 |

幅值不变不表示三相平方和直接等于 dq 平方和。本模块满足 a²+b²+c²=1.5*(d²+q²)+3*zero²；这是本次电流平方和关系（A²），不是通过当前测试直接测得的电功率。

## Scope 通道

四个 Scope 均只有一个输入端口，接收一组向量或标量；图例已开启，按向量元素顺序对应下表，不用颜色推断。纵轴自动缩放，ForwardSignals/InverseSignals/RoundTripErrors 的单位为 A，ElectricalAngle 为 rad；SampleTime=-1 继承 Ts。Scope 自身 DataLogging 未开启，全部数据由 SaveTrace 写入 out.ctTrace。

| Scope | 本地通道 | 记录列 | 名称 | 来源 | 观察内容 |
|---|---|---|---|---|---|
| ForwardSignals | 1 | 1 | a | TestInputs 第 1 列 | 原始三相电流 |
| ForwardSignals | 2 | 2 | b | TestInputs 第 2 列 | 原始三相电流 |
| ForwardSignals | 3 | 3 | c | TestInputs 第 3 列 | 原始三相电流 |
| ForwardSignals | 4 | 4 | alpha | Clarke 输出 1 | 固定坐标余弦分量 |
| ForwardSignals | 5 | 5 | beta | Clarke 输出 2 | 固定坐标正弦分量 |
| ForwardSignals | 6 | 6 | zero | Clarke 输出 3 | 平衡零和输入约为 0，含共模时非零 |
| ForwardSignals | 7 | 7 | d | Park 输出 1 | 默认应为 5 A |
| ForwardSignals | 8 | 8 | q | Park 输出 2 | 默认约为 0；角度超前时出现负值 |
| ElectricalAngle | 1 | 9 | theta_e | TestInputs 第 4 列 | 电角度，单独显示以免与电流单位混用 |
| InverseSignals | 1 | 10 | d_used | dSource | 反变换真正使用的 d |
| InverseSignals | 2 | 11 | q_used | qSource | 反变换真正使用的 q |
| InverseSignals | 3 | 12 | zero_used | ZeroSequenceTransfer | 实际保留或被丢弃的零序 |
| InverseSignals | 4 | 13 | alpha_recon | InversePark 输出 1 | 反旋转后的 α |
| InverseSignals | 5 | 14 | beta_recon | InversePark 输出 2 | 反旋转后的 β |
| InverseSignals | 6 | 15 | a_recon | InverseClarke 输出 1 | 重建 a |
| InverseSignals | 7 | 16 | b_recon | InverseClarke 输出 2 | 重建 b |
| InverseSignals | 8 | 17 | c_recon | InverseClarke 输出 3 | 重建 c |
| RoundTripErrors | 1 | 18 | error_a | ErrorA | a_recon−a |
| RoundTripErrors | 2 | 19 | error_b | ErrorB | b_recon−b |
| RoundTripErrors | 3 | 20 | error_c | ErrorC | c_recon−c |

只有 UseIndependentInverse=0 且 ZeroSequenceGain=1 时，误差组三条曲线才应接近零。独立命令不要求等于原 abc，丢弃零序会产生预期误差。自动缩放可能把 1e-15 量级舍入误差放大，判断应同时看纵轴数量级与 1e-12 A 容差。

建议先看 ForwardSignals 的 1–3 与 7–8，再看 InverseSignals 的 6–8 以及误差组。out.ctTrace.signals.values 的 20 列与记录列一致，时间为 out.ctTrace.time。批量数据在 results.mat 的 cases.<工况>.trace 中，另有 channels 列名。Scope 在批量运行后显示最后一轮，全部工况看保存数据和 [波形分析](../waveform_analysis/ANALYSIS.md)。

[运行与调参](../build_process/USAGE.md) · [返回模块](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 测试采样周期；变换积木本身继承调用周期 |

### 本模块局部量

$\theta_{frame}$是Park坐标角，$\theta_{ctrl}$是参考混合的目标坐标角；它们可由真实角、估角或软件场角给定，不自动等于$\theta_r$。工程输入名theta_e保持。原表$\theta_c$是交叉耦合电感补偿角，不用作控制坐标角。
