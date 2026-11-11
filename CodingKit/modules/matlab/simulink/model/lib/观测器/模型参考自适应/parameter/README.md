# MRAS参数与信号

## 配置参数

[mras_parameters.m](mras_parameters.m)定义默认值，[refresh_mras_parameters.m](refresh_mras_parameters.m)重算PI、滤波系数、连续资格拍数和17元素Settings。测试轨迹由[mras_test_parameters.m](mras_test_parameters.m)配置，重新加载入口为`initialize_mras_test('MrasObserverTest')`。

| 参数 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts / Rs / L / Flux / PolePairs | 50 μs / .5 / .001 / .035 / 4 | s、Ω、H、Wb、1 | SPMSM单L、永磁磁链及周期 |
| BandwidthHz / Damping | 30 / .7 | Hz / 1 | PI设计自然频率，Kp=2ζωn、Ki=ωn²，不作为实测闭环带宽 |
| Kaw | 20 | 1/s | 速度限幅后的PI回算 |
| ResidualCutoffHz | 500 | Hz | d/q电流残差一阶低通，工程添加；Alpha=Ts/(Ts+1/(2πfc)) |
| InitialAngle / InitialOmega | 0 / 300 | 电角rad / rad/s幅值 | 捕获初始先验，速度由direction指定符号 |
| MinBootstrapOmega / MaxOmega | 20 / 2000 | 电角rad/s | 有界归一化和带符号速度限制 |
| MinOmega / MinEmf | 30 / 1 | 电角rad/s / V | 运行资格的最低估速与反电势幅值 |
| MaxNormalizedD / MaxNormalizedQ | .12 / .3 | 1 | d相位残差和q幅值/分支一致性范围 |
| QualificationTime | .02 | s | 400拍连续满足资格；不满足立即清计数 |

测试默认由[mras_test_parameters.m](mras_test_parameters.m)定义：Duration=.5 s、InitialAngle=.7电角rad、ElectricalSpeed=600电角rad/s、Id=0/Iq=2 A、Direction=+1、Enable=1/Reset=0、NoiseRms=0 A/NoiseSeed=42、CurrentDelay=0拍、CheckStart=.35 s。电流年龄支持0/1拍，不同时移动电压；噪声和年龄修改后重新初始化。默认评分为角RMS<.08 rad、速度RMS<8电角rad/s、窗口有效比例≥.95，具体工况覆盖另见验证记录。

## 输入信号

按uα、uβ、iα、iβ、direction、enable、reset七个独立端口排列。u[k]是[kTs,(k+1)Ts)实际作用电压，保存后与i[k]一起参与下一拍预测。方向±1来自外部先验，0表示未知并重置；其他数值无效。reset优先于enable。真实θ/ω不进入库。

| 端口 | 名称 | 单位/类型 | 来源与用途 |
|---|---|---|---|
| 1 / 2 | u_alpha / u_beta | V，double | 对应采样区间实际作用电压；预测使用保存的上一拍值 |
| 3 / 4 | i_alpha / i_beta | A，double | 采样电流，先用估算角Park，再保存实测历史 |
| 5 | direction | −1/0/+1，double | 外部方向先验；0清捕获资格 |
| 6 / 7 | enable / reset | 0/1兼容double | 启用及清状态，reset优先 |

测试台FromWorkspace共九列：前七列同库输入，8/9为仅评分使用的真实电角rad及rad/s。当前输入生成器用理想作用电压，未加入逆变器或采样前端。

## 过程变量

21状态顺序：θ、速度积分、估速、上一拍实测id、iq、上一拍ud、uq、历史可用、滤波残差d/q、连续资格拍数、上一方向、模型预测id/iq、原始残差d/q、归一化d/q、估计反电势幅值、故障码、实际归一化分母。状态由UnitDelay保存，没有persistent。

`iCM[k]=iDQ[k−1]+Ts/L·(uDQ[k−1]−Rs·iDQ[k−1]+ωL·[iq;−id]−[0;ωψ])`，iDQ[k−1]必须是测得电流。分母KCM=Ts·ω·ψ/L，符号由方向先验保持，并设置最小幅值。d残差/分母经过±1限幅进入PI；q残差同时用于判断幅值及π分支一致性。重建反电势`[0;ωψ]−L/Ts·filteredResidual`用于幅值资格。低通、先验、限幅、资格和异常处理是本工程添加。

禁能、复位、未知方向清状态；方向正常变化重新捕获。非有限电压/电流产生故障1，无效控制/配置产生故障2，需禁能/复位清除。数据异常在下一拍的状态输出中反映，最多一个Ts；本库不代替功率级保护。

## 输出信号

| 输出端口 | 名称 | 单位 | 来源/作用 | trace列 |
|---|---|---|---|---|
| 1 / 2 / 3 | theta / omega / valid | 电角rad / rad/s / 0或1 | 当前保持状态及控制资格 | 10 / 11 / 12 |
| 4 / 5 | predicted_id / predicted_iq | A | 上一处理拍的一步预测 | 13 / 14 |
| 6 / 7 | measured_id / measured_iq | A | 同一处理拍的实测dq | 15 / 16 |
| 8 / 9 | raw_residual_d / raw_residual_q | A | 同一处理拍的测量减预测 | 17 / 18 |
| 10 / 11 | normalized_d / normalized_q | 1 | 低通后残差除实际分母 | 19 / 20 |
| 12 | emf_magnitude | V | 从电流模型残差重建的反电势幅值 | 21 |
| 13 | qualification_count | 拍 | 连续资格计数，最大400 | 22 |
| 14 | speed_integral | 电角rad/s | PI积分速度贡献 | 23 |
| 15 | fault | 0无故障、1数据异常、2控制/配置无效 | 状态或立即无效命令诊断 | 24 |
| 16 | normalization_denominator | A | 带符号且有下限的实际KCM | 25 |

单份ToWorkspace日志trace为N×26，前九列原输入，10–25列按输出端口顺序，26列为包角(theta_hat−theta_true)，单位电角rad。Structure With Time，采样Ts、不截断。θ/ω对应当前状态；4–16路诊断对应上一处理拍。保存的输入/时间允许复核年龄，不能把这些诊断直接与本拍电流相减。

## Scope 通道

每组Scope接一个向量，下表严格按向量实际顺序；列号为trace列。

| Scope | 通道顺序、名称与来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|
| AngleScope | 1真实Inputs.y8(8)；2估算Observer.y1(10)；3包角误差AngleError(26) | 电角rad | 捕获及±π包角 |
| SpeedScope | 1真实Inputs.y9(9)；2估算Observer.y2(11)；3积分Observer.y14(23) | 电角rad/s | 速度PI与积分贡献 |
| CurrentModelScope | 1实测id Observer.y6(15)；2预测id y4(13)；3实测iq y7(16)；4预测iq y5(14) | A | 同一处理拍的实测/预测关系 |
| ResidualScope | 1原始d残差Observer.y8(17)；2原始q残差y9(18) | A | 测量减预测 |
| NormalizedScope | 1归一化d Observer.y10(19)；2归一化q y11(20) | 1 | 相位误差近似和幅值/分支一致性 |
| EmfScope | 1重建幅值Observer.y12(21) | V | 激励是否足够 |
| NormalizerScope | 1实际分母Observer.y16(25) | A | 方向符号与低速下限 |
| StatusScope | 1方向Inputs.y5(5)；2使能y6(6)；3复位y7(7)；4有效Observer.y3(12)；5连续计数y13(22)；6故障y15(24) | ±1/0、0/1、拍、枚举 | 启用、连续资格、拒绝及故障 |

先看角度/速度和StatusScope，再按问题查看电流模型、归一化残差或分母。查看后关闭Scope，不同时打开全部图窗。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d=L_q$ | cfg.L | H | SPMSM公共电感；原表mH乘$10^{-3}$，局部符号$\ell_{sp}$ |
| $\psi_m$ | cfg.Flux | Wb | 直接使用 |
| $P$ | cfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | cfg.InitialAngle | 电角rad | 初始估角先验，直接使用 |
| $\hat\omega_r$ | direction × cfg.InitialOmega | 电角rad/s | 初始估速先验；MRAS字段存正幅值，由direction赋号 |

### 本模块局部量

$\ell_{sp}=L_d=L_q$为本SPMSM公共电感，工程L使用H；原表$L$特指BLDC相自感，不作该工程字段的物理定义。$\omega_{raw}$是未限幅PI请求，$\hat\omega_r$才是估计电转子速度；两者均不等于真实速度$\omega_r$。

## 主机代码检查配置与数据

[mras_host_test_parameters.m](mras_host_test_parameters.m)是[主机验证脚本](../waveform_analysis/run_mras_host_validation.m)的参数入口，继承独立MIL默认值；修改后重新运行脚本。SLX默认仍为double，原8组Scope及26列trace保持。

| 字段 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Duration / CheckStart | .1 / .08 | s | 终点/评分起点，2001个50 μs采样点 |
| InitialAngle / ElectricalSpeed | .7 / 600 | 电角rad / 电角rad/s | 解析真实轨迹，只造输入与评分 |
| Id / Iq / Direction | 0 / 2 / +1 | A / A / 方向 | 恒定真实dq电流与已知方向先验 |
| AngleRmsLimit / SpeedRmsLimit | .08 / 8 | 电角rad / 电角rad/s | 评分窗口RMS上限 |
| ValidFractionMinimum | .95 | 比例 | 资格计数达到连续拍数的时间比例下限 |
| MexDoubleRelativeLimit / MexSingleRelativeLimit | $10^{-8}$ / $10^{-3}$ | 相对值 | 生成代码对同类型MATLAB状态误差上限 |
| SilDoubleRelativeLimit | $10^{-8}$ | 相对值 | 独立double C库SIL状态误差上限 |

独立输入满足$u_{\alpha\beta}=R_si_{\alpha\beta}+\ell_{sp}\,\mathrm{d}i_{\alpha\beta}/\mathrm{d}t+e_{\alpha\beta}$；真实角度/速度不进入算法。`physical_fixture.mat`保存time(s)、theta(真实电角rad)、current(α/β，A)、voltage(α/β，V)、cfg/test和reference/singleReference。三个`*_trace.mat`保存N×21状态，列序与[21状态表](../build_process/STEPS.md#4-21个显式状态和复位)一致，记录更新前状态；MEX中actual/expected为生成代码/同类型MATLAB，SIL中actual/reference为独立C库/双精度MATLAB。第11、12、20列资格计数、方向、故障额外要求完全一致。

相对误差逐元素计算$\lvert x_\mathrm{code}-x_\mathrm{MATLAB}\rvert/\max(1,\lvert x_\mathrm{MATLAB}\rvert)$后取最大值，混合单位状态误差不当成电流误差。主机脚本用MAT/JSON记录，未新增Scope；数据见[主机分析](../waveform_analysis/HOST_CODE_ANALYSIS.md)。
