# EKF参数与信号

## 配置参数

[ekf_parameters.m](ekf_parameters.m)组合本模块协方差/资格和pmsm_plant的SPMSM参数。[refresh_kalman_parameters.m](refresh_kalman_parameters.m)重算P0、离散Q、R和27项Settings。修改后调用`initialize_ekf_test('EkfObserverTest')`。完整运行、SimulationInput临时覆盖与重建见[USAGE.md](../build_process/USAGE.md)。P0、Q、R是协方差，单位为对应状态单位的乘积；不能直接当作PI增益。

| 名称 | 默认值 | 单位 | 作用 |
|---|---|---|---|
| Model.Ts/Rs/L/Flux/PolePairs | 50 μs/.5/.001/.035/4 | SI | 四状态SPMSM过程 |
| InitialOmega/InitialAngle | 300/0 | 电角rad/s幅值、电角rad | 第一次启用按方向先验设定速度，角度包角 |
| InitialStd | [1;1;500;.5] | A、A、rad/s、rad | 初始标准差，P0取平方对角 |
| ProcessNoiseDensity | [2;2;2000;1e−5] | 对应状态方差/s | 每步Q=Density·Ts |
| MeasurementStd | [.002;.002] | A | R为电流噪声方差对角 |
| QualificationTime/MinOmega/MinEmf | .02/30/1 | s、电角rad/s、V | 连续资格与激励范围 |
| MaxNIS/MaxThetaStd/MaxOmegaStd | 25/.12/100 | 1、rad、rad/s | 创新和配置模型中的不确定度限制 |
| AngleRateTimeConstant/MaxRateMismatch | .002/60 | s、电角rad/s | 估算角差分低通，与估速核对相反速度分支 |
| MaxOmega/MaxInputCurrent/MaxInputVoltage | 2000/100/1000 | 电角rad/s、A、V | 观测模型数值范围，不代替功率级保护 |

测试入口为[ekf_test_parameters.m](ekf_test_parameters.m)：

| 名称 | 默认值 | 单位 | 用途 |
|---|---|---|---|
| Duration/CheckStart | .5/.35 | s | 仿真终点及默认评分起点 |
| InitialAngle/ElectricalSpeed | .7/600 | 电角rad、rad/s | 真实轨迹初角和速度，与估计初值区分 |
| Id/Iq | 0/2 | A | 真实dq电流 |
| Direction/Enable/Reset | 1/1/0 | 控制值 | 默认方向先验/启用/复位 |
| NoiseRms/NoiseSeed | 0/42 | A、整数 | 电流噪声与随机种子 |
| CurrentDelay | 0 | 拍 | 0为同拍；测试1拍时仅移位电流 |
| AngleRmsLimit/SpeedRmsLimit | .08/8 | 电角rad、rad/s | 正常工况RMS门限 |
| ValidFractionMinimum | .95 | 1 | 评分窗口最低资格比例 |

27项Settings顺序为Ts/Rs/L/Flux、初速幅值/初角、P0对角4、Q对角4、R对角2、资格拍数、MinOmega、MinEmf、MaxNIS、MaxThetaStd、MaxOmegaStd、角变化率低通系数、MaxRateMismatch、MaxOmega、MaxInputCurrent、MaxInputVoltage。低通系数由Ts/(AngleRateTimeConstant+Ts)刷新。不要在SLX逐元素修改派生向量。

## 输入信号

七输入依次如下，周期均为cfg.Model.Ts，类型均为double：

| 端口/日志列 | 名称 | 单位 | 来源与用途 |
|---|---|---|---|
| 1/1 | uα | V | 实际作用电压；下一拍预测 |
| 2/2 | uβ | V | 实际作用电压；下一拍预测 |
| 3/3 | iα | A | 采样电流；本拍校正 |
| 4/4 | iβ | A | 采样电流；本拍校正 |
| 5/5 | direction | −1/0/+1 | 外部方向先验，不使用真实速度作在线判锁 |
| 6/6 | enable | 0/1 | 禁能清状态及资格 |
| 7/7 | reset | 0/1 | 复位恢复P0和初值 |

测试输入另外两列8/9为真实θe/rad及ωe/rad/s，只进入对照和日志。当前i[k]校正本拍先验；当前u[k]只预测[k+1]，避免电压反馈代数环。方向±1为先验/资格条件，0为未知，禁止valid但继续估计；方向改变清连续资格，不丢弃已有位置状态。禁能/复位重新初始化。

## 过程变量

28保持量依次为先验状态4、先验P按列展开16、连续计数、上一后验角、低通角变化率、角历史有效、上一方向、故障、已初始化、数值修复计数。状态及完整4×4协方差显式保存。P/Q/R的单位随状态变化，不能把三者当作同一单位的增益。

## 输出信号

已实现24个标量诊断和第25端口16元素后验协方差；均为double、周期Ts。下表日志列针对统一后的N×50 trace：

| 输出端口 | 日志列 | 名称 | 单位 | 来源/用途 |
|---|---|---|---|---|
| 1 | 10 | theta | 电角rad | 后验θ，包角到±π |
| 2 | 11 | omega | 电角rad/s | 后验ω，带方向 |
| 3 | 12 | valid | 0/1 | 连续资格结果 |
| 4/5 | 13/14 | i_alpha_hat/i_beta_hat | A | 本拍后验电流 |
| 6/7 | 15/16 | innovation_alpha/beta | A | 当前实测电流减先验电流 |
| 8 | 17 | NIS | 1 | innovationᵀ·S⁻¹·innovation |
| 9 | 18 | theta_std | 电角rad | sqrt(Pθθ) |
| 10 | 19 | omega_std | 电角rad/s | sqrt(Pωω) |
| 11 | 20 | angle_rate | 电角rad/s | 相邻后验θ包角差分低通 |
| 12 | 21 | rate_mismatch | 电角rad/s | angle_rate−omega |
| 13 | 22 | qualification_count | 拍 | 连续符合条件的拍数，默认封顶400 |
| 14 | 23 | fault | 枚举 | 0正常、1输入、2控制/配置、3数值 |
| 15/16 | 24/25 | P_ia/P_ib | A² | 后验P对角 |
| 17 | 26 | P_omega | (电角rad/s)² | 后验P对角 |
| 18 | 27 | P_theta | 电角rad² | 后验P对角 |
| 19/20 | 28/29 | K_theta_alpha/beta | rad/A | 本拍角度校正增益 |
| 21/22 | 30/31 | K_omega_alpha/beta | (rad/s)/A | 本拍速度校正增益 |
| 23 | 32 | emf_magnitude | V | abs(omega)·Flux；模型激励量 |
| 24 | 33 | numerical_repairs | 次 | EKF始终为0；共用诊断接口 |
| 25 | 34–49 | posterior_P(:) | 各状态单位乘积 | 4×4按列展开，完整矩阵逐拍检查 |
| 测试台 | 50 | wrapped_angle_error | 电角rad | atan2(sin(估计−真实),cos(估计−真实)) |

1–9列为上述测试输入。协方差对应配置Q/R下的估计，不直接等于实际误差保证；P0/Q/R由M入口定义，创新和P/K由KalmanMeasurement产生，下一先验由Predict写入PriorMemory。

## Scope 通道

实际EkfObserverTest中有下列10个Scope。每行按实际Mux顺序，输入源Inputs为测试输入Demux，Observer为完整EKF输出。单位保持电角量；状态Scope含400拍计数，观察标志时可在图例中隐藏计数。增益和完整P只记录，不声称已有Scope。

| Scope | 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---:|---|---|---|---|
| AngleScope | 1 | true_theta | Inputs/8，列8 | rad/double | 真实角，仅对照 |
| AngleScope | 2 | theta | Observer/1，列10 | rad/double | 本拍后验角 |
| AngleScope | 3 | angle_error | AngleError，列50 | rad/double | 包角误差 |
| SpeedScope | 1 | true_omega | Inputs/9，列9 | rad/s/double | 真实电角速度 |
| SpeedScope | 2 | omega | Observer/2，列11 | rad/s/double | 估速 |
| SpeedScope | 3 | angle_rate | Observer/11，列20 | rad/s/double | 相反速度分支核对 |
| CurrentScope | 1 | measured_i_alpha | Inputs/3，列3 | A/double | 电流测量 |
| CurrentScope | 2 | estimated_i_alpha | Observer/4，列13 | A/double | 后验电流 |
| CurrentScope | 3 | measured_i_beta | Inputs/4，列4 | A/double | 电流测量 |
| CurrentScope | 4 | estimated_i_beta | Observer/5，列14 | A/double | 后验电流 |
| InnovationScope | 1 | innovation_alpha | Observer/6，列15 | A/double | α创新 |
| InnovationScope | 2 | innovation_beta | Observer/7，列16 | A/double | β创新 |
| NisScope | 1 | NIS | Observer/8，列17 | 1/double | 默认资格上限25 |
| AngleSigmaScope | 1 | theta_std | Observer/9，列18 | rad/double | 默认上限0.12 |
| SpeedSigmaScope | 1 | omega_std | Observer/10，列19 | rad/s/double | 默认上限100 |
| RateMismatchScope | 1 | rate_mismatch | Observer/12，列21 | rad/s/double | 默认绝对上限60 |
| EmfScope | 1 | emf_magnitude | Observer/23，列32 | V/double | 默认最低1 V |
| StatusScope | 1 | direction | Inputs/5，列5 | 命令/double | 方向先验 |
| StatusScope | 2 | enable | Inputs/6，列6 | 0/1/double | 启用 |
| StatusScope | 3 | reset | Inputs/7，列7 | 0/1/double | 复位 |
| StatusScope | 4 | valid | Observer/3，列12 | 0/1/double | 资格 |
| StatusScope | 5 | qualification_count | Observer/13，列22 | 拍/double | 连续计数 |
| StatusScope | 6 | fault | Observer/14，列23 | 枚举/double | 锁存故障 |
| StatusScope | 7 | numerical_repairs | Observer/24，列33 | 次/double | EKF为0 |

运行测试台后打开当前要看的Scope，查看完关闭；批量脚本不开启额外窗口。

[模块入口](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Model.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Model.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d=L_q$ | cfg.Model.L | H | SPMSM公共电感；原表mH乘$10^{-3}$，局部符号$\ell_{sp}$ |
| $\psi_m$ | cfg.Model.Flux | Wb | 直接使用 |
| $P$ | cfg.Model.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | cfg.InitialAngle | 电角rad | 初始估角先验，直接使用 |
| $\hat\omega_r$ | cfg.InitialOmega | 电角rad/s | 初始估速先验，直接使用 |

### 本模块局部量

$\ell_{sp}=L_d=L_q$为SPMSM公共电感。$\mathbf P$是四状态协方差，$P$保留极对数意义；协方差元素单位为对应两状态单位之积。Model.L使用H，InitialAngle/InitialOmega为估计电角rad/rad/s先验。
