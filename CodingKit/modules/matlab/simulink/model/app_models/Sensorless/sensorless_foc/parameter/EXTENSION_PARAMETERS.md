# MRAS、EKF、UKF与sigmoid物理闭环参数

本页只说明新增四份桥耦合App。原三份平均模型与FlyingFluxFOC的参数/日志保持各自格式，入口仍在[README](README.md)。本页默认值来自实际M参数快照，Scope顺序来自编译后的端口清单。

## 配置参数

可执行入口为[extension_foc_parameters.m](extension_foc_parameters.m)，离线选择`'mras'/'ekf'/'ukf'/'sigmoid'`；它组合共用配置并在本模块覆盖SPMSM、速度给定、观测器和互锁。派生值通过[refresh_extension_foc_parameters.m](refresh_extension_foc_parameters.m)刷新。模型对应由[extension_foc_spec.m](extension_foc_spec.m)固定。这不是运行中无缝切换算法。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $R_s$ | pmsmCfg.Rs；observerCfg.Rs或observerCfg.Model.Rs | Ω | 分别是真实电机和观测模型，默认相同，允许独立偏差 |
| $L_d,L_q$ | pmsmCfg.Ld/Lq | H | 原表mH乘$10^{-3}$；四App限定两者相等 |
| $L_d=L_q$；本页局部$ell_{sp}$ | observerCfg.L或observerCfg.Model.L | H | SPMSM公共电感；不把原表BLDC相自感$L$重新定义为SPMSM量 |
| $psi_m$ | pmsmCfg.Flux；observerCfg[.Model].Flux | Wb | 默认相同，可独立配置观测偏差 |
| $P$ | pmsmCfg.PolePairs | 计数 | 原表单位空白，不补填；数值不换算 |
| $	heta_r,hat	heta_r$ | Plant.theta_e；Observer.theta_hat | 电角rad | 真实角用于物理换算/评分，估计角参与控制 |
| $omega_r,hatomega_r$ | P×Plant.speed_mechanical；Observer.omega_hat | 电角rad/s | 估计机械速度为omega_hat/P |
| $omega_m$ | focCfg.SpeedReference、实际机械速度 | 机械rad/s | 参考量加*标记；80rad/s约764rpm |
| $T_{m_BLAC},T_L$ | Plant.torque；load_torque | N·m | 正负号按机械方程明确 |
| $V_{dc}$ | fwCfg.BusValues、testStim第7列 | V | 实际母线，控制器/调制/物理桥共用 |

[用户符号表](../../../../../docs/userdocs/符号定义表.md)原文保持不变。局部$b_{rot}$映射真实电机旋转阻尼pmsmCfg.B（N·m·s/rad）；原书$B$是N·s/m，不能直接换算。局部$artheta_{shaft}$为展开机械轴角，映射Position0/机械状态；原书$	heta_m$为交叉饱和角。控制坐标角记$	heta_{ctrl}$，不占用原书交叉电感补偿角$	heta_c$。Kalman协方差记$mathbf P$，与极对数$P$区分。sigmoid的工程A/B系数另记$a_i,b_i$，后者单位A/V。

### 共同默认配置

四App共同默认值以下列一份表登记。`refCfg.MtpaEnable/FwEnable`固定0供本批SPMSM对照，refresh拒绝开启；高速弱磁另用[已建弱磁App](../../sensorless_fw/README.md)。FW滤波/积分参数和MTPA查表在本批不参与调节，MaxTorque仍用于转矩速度环的限值。修改物理电机、周期后需同步对应控制器和观测配置；refresh不会重新整定环路。

#### pmsmCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `pmsmCfg.Rs` | 0.5 | Ω | 定子相电阻 |
| `pmsmCfg.Ld` | 0.001 | H | d轴电感 |
| `pmsmCfg.Lq` | 0.001 | H | q轴电感 |
| `pmsmCfg.Flux` | 0.035 | Wb | 永磁体磁链 |
| `pmsmCfg.PolePairs` | 4 | 计数 | 极对数 |
| `pmsmCfg.J` | 0.0005 | kg·m² | 转动惯量 |
| `pmsmCfg.B` | 0.0001 | N·m·s/rad | 本模型局部旋转黏性阻尼，见符号映射 |
| `pmsmCfg.Id0` | 0 | A | 初始真实d电流 |
| `pmsmCfg.Iq0` | 0 | A | 初始真实q电流 |
| `pmsmCfg.Speed0` | 0 | 机械rad/s | 物理机械初速 |
| `pmsmCfg.Position0` | 0.1 | 机械rad | 物理机械初始位置，电角为P倍 |

#### currentCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `currentCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `currentCfg.BandwidthHz` | 500 | Hz | 名义带宽 |
| `currentCfg.Kpd` | 3.141592653589793 | V/A | d轴比例增益 |
| `currentCfg.Kpq` | 3.141592653589793 | V/A | q轴比例增益 |
| `currentCfg.Kid` | 1570.7963267948965 | V/(A·s) | d轴积分增益 |
| `currentCfg.Kiq` | 1570.7963267948965 | V/(A·s) | q轴积分增益 |
| `currentCfg.Kaw` | 20000 | 1/s | 抗饱和回算增益 |

#### inverterCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `inverterCfg.Vdc` | 48 | V | 名义母线；实际母线由输入覆盖 |
| `inverterCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `inverterCfg.PwmTs` | 5e-05 | s | PWM名义周期 |
| `inverterCfg.LinearLimit` | 26.604300404257955 | V | 派生电压圆半径 |

#### timingCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `timingCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `timingCfg.FeedbackTicks` | 0 | 拍 | 测量延迟拍数 |
| `timingCfg.ActuationTicks` | 1 | 拍 | 占空比执行延迟拍数 |

#### motionCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `motionCfg.SpeedLimit` | 120 | 机械rad/s | 斜坡速度限值 |
| `motionCfg.AccelerationLimit` | 200 | 机械rad/s² | 斜坡加速度限值 |

#### experimentCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `experimentCfg.UseTiming` | 1 | 标志 | 选择有执行延迟的占空比 |
| `experimentCfg.Step` | 5e-06 | s | 物理对象及固定求解步长 |
| `experimentCfg.Duration` | 2.2 | s | 停止时间 |

#### focCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `focCfg.Direction` | 1 | ±1 | 给定旋转方向及观测EMF符号 |
| `focCfg.SpeedReference` | 80 | 机械rad/s | 默认最终机械速度给定 |
| `focCfg.SpeedInitial` | 0 | 机械rad/s | 给定斜坡初值，不是物理初速 |
| `focCfg.CommandTime` | 0.05 | s | 速度命令阶跃时刻 |
| `focCfg.LoadTorque` | 0.1 | N·m | 阶跃后外负载 |
| `focCfg.LoadTime` | 0.9 | s | 负载阶跃时刻 |
| `focCfg.Enable` | 1 | 标志 | 默认总请求使能 |
| `focCfg.Reset` | 0 | 标志 | 默认复位输入 |
| `focCfg.ObserverEnable` | 1 | 标志 | 默认观测器使能 |
| `focCfg.VoltageAlignmentEnable` | 1 | 标志 | 启动对齐电压支路使能 |
| `focCfg.AlignmentVoltageGain` | 0.5 | V/A | 对齐电流转换到电压的增益 |
| `focCfg.FrameCorrectionTolerance` | 1e-10 | 电角rad | 额外坐标角修正阈值 |

#### refCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `refCfg.MtpaEnable` | 0 | 标志 | 使能MTPA查表；本批对应功能关闭 |
| `refCfg.FwEnable` | 0 | 标志 | 使能弱磁状态；本批对应功能关闭 |
| `refCfg.CurrentMax` | 8 | A | 参考电流矢量半径 |
| `refCfg.IdMin` | -7 | A | 参考d电流下界 |
| `refCfg.VoltageReserve` | 0.95 | 1 | 分配器电压预留比例 |
| `refCfg.FwVoltageMargin` | 0.2 | V | 弱磁目标额外电压余量；本批对应功能关闭 |
| `refCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `refCfg.FwTs` | 0.001 | s | 弱磁滤波/积分周期；本批对应功能关闭 |
| `refCfg.FilterTau` | 0.003 | s | 弱磁需求低通时间常数；本批对应功能关闭 |
| `refCfg.FwKi` | 50 | A/(V·s) | 电压误差到d电流的积分增益；本批对应功能关闭 |
| `refCfg.IdSlew` | 200 | A/s | 弱磁d电流每秒最大变化；本批对应功能关闭 |
| `refCfg.TablePoints` | 257 | 点 | MTPA生成表点数 |
| `refCfg.SpeedTs` | 0.001 | s | 转矩速度PI周期 |
| `refCfg.SpeedKp` | 0.017900000000000003 | N·m/(rad/s) | 转矩速度PI比例增益 |
| `refCfg.SpeedKi` | 0.2 | N·m/rad | 转矩速度PI积分增益 |
| `refCfg.SpeedKaw` | 1000 | 1/s | 分配转矩回算增益 |
| `refCfg.IdTable` | 257项派生向量，见参数M和快照 | A | 由电机和电流圆生成的MTPA负d表 |
| `refCfg.TorqueGrid` | 257项派生向量，见参数M和快照 | N·m | 与IdTable一一对应的转矩网格 |
| `refCfg.MaxTorque` | 1.6800000000000002 | N·m | MTPA表最大转矩 |
| `refCfg.Kt` | 0.21000000000000002 | N·m/A | 零d电流名义转矩常数 |
| `refCfg.VoltageFactor` | 0.5265434455009387 | 1 | 电压预留/最小占空比派生比例 |
| `refCfg.FilterAlpha` | 0.75 | 1 | 由FilterTau和FwTs派生低通系数；本批对应功能关闭 |

#### startupCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `startupCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `startupCfg.Theta0` | 0 | 电角rad | 软件启动/PLL初始电角度 |
| `startupCfg.AlignCurrent` | 2 | A | 对齐d电流 |
| `startupCfg.StartupCurrent` | 3 | A | I-f阶段q电流 |
| `startupCfg.FinalOmega` | 250 | 电角rad/s | I-f最终电角速度 |
| `startupCfg.FlyingCaptureTime` | 0.03 | s | 共用启动器带速观察参数，本App不启用带速接管 |
| `startupCfg.PrealignTime` | 0.06 | s | 预对齐总时间 |
| `startupCfg.PrealignRampTime` | 0.03 | s | 预对齐斜坡时间 |
| `startupCfg.AlignTime` | 0.08 | s | 固定角对齐总时间 |
| `startupCfg.AlignRampTime` | 0.04 | s | 对齐电流斜坡时间 |
| `startupCfg.OmegaRampTime` | 0.35 | s | I-f角速度爬坡时间 |
| `startupCfg.CurrentRampTime` | 0.05 | s | I-f电流爬坡时间 |
| `startupCfg.MinCaptureOmega` | 150 | 电角rad/s | 启动器最小捕获速度 |
| `startupCfg.MaxIFTime` | 0.8 | s | I-f最大等待时间 |
| `startupCfg.Samples` | [600,1200,600,1600,800,7000,1000,16000] | 拍 | 由秒数和Ts派生的计数向量 |
| `startupCfg.Vector` | [5e-05,0,2,3,250,600,1200,600,1600,800,7000,1000,16000,150] | 逐项SI/标志 | 打包后的库配置向量，按refresh生成 |
| `startupCfg.State0` | [0,0,0,0,0] | 逐项SI/计数 | 物理/控制状态初值，按refresh生成 |

#### handoverCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `handoverCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `handoverCfg.MinOmega` | 100 | 电角rad/s | 最小资格电角速度 |
| `handoverCfg.MaxSpeedGap` | 80 | 电角rad/s | 启动与观测速度允许差 |
| `handoverCfg.MaxPhaseGap` | 0.9 | 电角rad | 启动与观测包角差上限 |
| `handoverCfg.MaxResidual` | 1.5 | A | 观测电流残差资格上限 |
| `handoverCfg.CaptureTime` | 0.01 | s | 持续资格时间 |
| `handoverCfg.BlendTime` | 0.1 | s | 角度/给定混合时间 |
| `handoverCfg.LossTime` | 0.001 | s | 闭环丢锁持续退出时间 |
| `handoverCfg.MaxPhaseInnovation` | 0.15 | 电角rad | 单拍估角变化创新界 |
| `handoverCfg.AllowFlying` | 0 | 标志 | 本App为0，不从旋转中直接带速接管 |
| `handoverCfg.Samples` | [200,2000,20] | 拍 | 由秒数和Ts派生的计数向量 |
| `handoverCfg.Vector` | [5e-05,100,80,0.9,1.5,200,2000,20,0.15,0] | 逐项SI/计数 | 打包后的库配置向量，按refresh生成 |
| `handoverCfg.State0` | [0,0,0,0,0,0,0,0,0] | 逐项SI/计数 | 物理/控制状态初值，按refresh生成 |

#### fwCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `fwCfg.BusTimes` | 0 | s | 实际母线分段保持事件时刻，首项0 |
| `fwCfg.BusValues` | 48 | V | 对应实际母线，每项必须正有限 |

#### startGuardCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `startGuardCfg.Enable` | 1 | 标志 | 启动互锁开关，默认1；0仅供明确的绕过对照 |
| `startGuardCfg.ObserveTime` | 0.05 | s | 允许启动前连续观察时间 |
| `startGuardCfg.ObserveTicks` | 1000 | 拍 | ceil(ObserveTime/currentCfg.Ts) |
| `startGuardCfg.MaxStartVoltage` | 0.25 | V | 允许初次启动/重启的实际端电压αβ幅值上限，当前0.25V |

#### bridgeCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `bridgeCfg.Rs` | 0.5 | Ω | 定子相电阻；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Ld` | 0.001 | H | d轴电感；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Lq` | 0.001 | H | q轴电感；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Flux` | 0.035 | Wb | 永磁体磁链；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.PolePairs` | 4 | 计数 | 极对数；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.J` | 0.0005 | kg·m² | 转动惯量；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.B` | 0.0001 | N·m·s/rad | 本模型局部旋转黏性阻尼，见符号映射；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Id0` | 0 | A | 初始真实d电流；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Iq0` | 0 | A | 初始真实q电流；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Speed0` | 0 | 机械rad/s | 物理机械初速；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Position0` | 0.1 | 机械rad | 物理机械初始位置，电角为P倍；由真实pmsmCfg同步覆盖 |
| `bridgeCfg.Ts` | 5e-06 | s | 本结构所用离散周期 |
| `bridgeCfg.Vdc` | 48 | V | 名义母线；实际母线由输入覆盖 |
| `bridgeCfg.DiodeVf` | 0.7 | V | 关断二极管正向压降 |
| `bridgeCfg.DiodeRon` | 0.01 | Ω | 二极管正向等效电阻 |
| `bridgeCfg.MechanicalEnabled` | 1 | 标志 | 物理机械状态积分使能 |
| `bridgeCfg.CurrentTolerance` | 1e-09 | A | 桥活动集电流数值容差 |
| `bridgeCfg.VoltageTolerance` | 1e-08 | V | 桥活动集电压数值容差 |
| `bridgeCfg.MaxCurrent` | 200 | A | 物理电流断言界，不是限流器 |
| `bridgeCfg.MaxSpeed` | 1000 | 机械rad/s | 物理机械速度断言界 |
| `bridgeCfg.MaxAngleStep` | 0.1 | 电角rad | 每物理拍最大电角步长 |
| `bridgeCfg.State0` | [0,0,0,0.1] | 逐项SI | 物理/控制状态初值，按refresh生成 |
| `bridgeCfg.Vector` | 17项派生向量，见参数M和快照 | 逐项SI/标志 | 打包后的库配置向量，按refresh生成 |

#### normalizedInverterCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `normalizedInverterCfg.Vdc` | 1 | 归一化基准 | 局部归一化1V基准，不是实际物理母线；命令先除实际Vdc后进入此实例 |
| `normalizedInverterCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `normalizedInverterCfg.PwmTs` | 5e-05 | s | PWM名义周期 |
| `normalizedInverterCfg.LinearLimit` | 0.5542562584220407 | 归一化电压 | 派生电压圆半径 |

### MRAS观测配置

`extensionCfg.Kind="mras"`匹配`MrasSensorlessFOC.slx`，输入选择符不进入观测数值内核。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `observerCfg.Ts` | 5e-05 | s | 观测更新周期 |
| `observerCfg.Rs` | 0.5 | Ω | 观测模型电阻，允许与真实电机独立覆盖 |
| `observerCfg.L` | 0.001 | H | 局部SPMSM公共电感ℓ_sp；名义等于Ld=Lq，允许观测模型偏差 |
| `observerCfg.Flux` | 0.035 | Wb | 观测模型永磁磁链 |
| `observerCfg.PolePairs` | 4 | 计数 | 观测配置的极对数 |
| `observerCfg.BandwidthHz` | 30 | Hz | MRAS名义PI设计频率 |
| `observerCfg.Damping` | 0.7 | 1 | MRAS设计阻尼比 |
| `observerCfg.Kaw` | 20 | 1/s | MRAS速度限幅回算增益 |
| `observerCfg.ResidualCutoffHz` | 500 | Hz | 一步电流残差低通截止频率 |
| `observerCfg.InitialAngle` | 0 | 电角rad | 估计初始电角，非Plant真实角 |
| `observerCfg.InitialOmega` | 300 | 电角rad/s | 估速初值/方向初始化幅值；MRAS需不小于bootstrap下界，Kalman本App为0 |
| `observerCfg.MinBootstrapOmega` | 20 | 电角rad/s | MRAS归一化分母/估速的正下界 |
| `observerCfg.MaxOmega` | 2000 | 电角rad/s | 估速上界 |
| `observerCfg.MinOmega` | 30 | 电角rad/s | 最小资格电角速度 |
| `observerCfg.MinEmf` | 1 | V | 最小反电势幅值资格 |
| `observerCfg.MaxNormalizedD` | 0.12 | 1 | MRAS归一化d残差绝对界 |
| `observerCfg.MaxNormalizedQ` | 0.3 | 1 | MRAS归一化q残差绝对界 |
| `observerCfg.QualificationTime` | 0.02 | s | 连续满足观测资格的时间 |
| `observerCfg.Kp` | 263.8937829015426 | 电角rad/s / 归一化误差 | MRAS由频率/阻尼派生的比例增益 |
| `observerCfg.Ki` | 35530.57584392168 | 电角rad/s² / 归一化误差 | MRAS由频率派生的积分增益 |
| `observerCfg.ResidualAlpha` | 0.13575524816363319 | 1 | 残差低通更新系数 |
| `observerCfg.QualificationSamples` | 400 | 拍 | 由QualificationTime/Ts派生的计数 |
| `observerCfg.Settings` | 17项派生向量，见参数M和快照 | 逐项SI/计数 | 供库mask使用的派生配置向量，修改上游值后refresh |

### EKF观测配置

`extensionCfg.Kind="ekf"`匹配`EkfSensorlessFOC.slx`，输入选择符不进入观测数值内核。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `observerCfg.Model.Ts` | 5e-05 | s | 观测更新周期 |
| `observerCfg.Model.Rs` | 0.5 | Ω | 观测模型电阻，允许与真实电机独立覆盖 |
| `observerCfg.Model.L` | 0.001 | H | 局部SPMSM公共电感ℓ_sp；名义等于Ld=Lq，允许观测模型偏差 |
| `observerCfg.Model.Flux` | 0.035 | Wb | 观测模型永磁磁链 |
| `observerCfg.Model.PolePairs` | 4 | 计数 | 观测配置的极对数 |
| `observerCfg.InitialOmega` | 0 | 电角rad/s | 估速初值/方向初始化幅值；MRAS需不小于bootstrap下界，Kalman本App为0 |
| `observerCfg.InitialAngle` | 0 | 电角rad | 估计初始电角，非Plant真实角 |
| `observerCfg.InitialStd` | [1,1,500,0.5] | [A,A,电角rad/s,电角rad] | 四状态初始标准差，状态顺序iα、iβ、ωr、θr |
| `observerCfg.ProcessNoiseDensity` | [2,2,2000,1e-05] | [A²/s,A²/s,电角rad²/s³,电角rad²/s] | 四状态方差密度；乘Ts得到每步过程方差 |
| `observerCfg.MeasurementStd` | [0.002,0.002] | A RMS | 每次电流测量标准差假设；当前App未额外注入测量噪声 |
| `observerCfg.QualificationTime` | 0.02 | s | 连续满足观测资格的时间 |
| `observerCfg.MinOmega` | 30 | 电角rad/s | 最小资格电角速度 |
| `observerCfg.MinEmf` | 1 | V | 最小反电势幅值资格 |
| `observerCfg.MaxNIS` | 25 | 1 | 归一化创新平方的资格上限 |
| `observerCfg.MaxThetaStd` | 0.12 | 电角rad | 后验估角标准差资格上限，不是真实角误差上限 |
| `observerCfg.MaxOmegaStd` | 100 | 电角rad/s | 后验估速标准差资格上限 |
| `observerCfg.AngleRateTimeConstant` | 0.002 | s | 后验角变化率低通时间常数 |
| `observerCfg.MaxRateMismatch` | 60 | 电角rad/s | 后验角变化率与估速状态的允许差 |
| `observerCfg.MaxOmega` | 2000 | 电角rad/s | 估速上界 |
| `observerCfg.MaxInputCurrent` | 100 | A | 观测输入电流保护界 |
| `observerCfg.MaxInputVoltage` | 1000 | V | 观测输入电压保护界 |
| `observerCfg.InitialVariance` | [1,1,250000,0.25] | 状态单位平方 | InitialStd逐项平方 |
| `observerCfg.ProcessVariance` | [0.0001,0.0001,0.1,5e-10] | 状态单位平方 | ProcessNoiseDensity乘Model.Ts |
| `observerCfg.MeasurementVariance` | [4e-06,4e-06] | A² | MeasurementStd逐项平方 |
| `observerCfg.QualificationSamples` | 400 | 拍 | 由QualificationTime/Ts派生的计数 |
| `observerCfg.AngleRateAlpha` | 0.024390243902439025 | 1 | 角变化率滤波派生系数 |
| `observerCfg.Settings` | 27项派生向量，见参数M和快照 | 逐项SI/计数 | 供库mask使用的派生配置向量，修改上游值后refresh |

### UKF观测配置

`extensionCfg.Kind="ukf"`匹配`UkfSensorlessFOC.slx`，输入选择符不进入观测数值内核。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `observerCfg.Model.Ts` | 5e-05 | s | 观测更新周期 |
| `observerCfg.Model.Rs` | 0.5 | Ω | 观测模型电阻，允许与真实电机独立覆盖 |
| `observerCfg.Model.L` | 0.001 | H | 局部SPMSM公共电感ℓ_sp；名义等于Ld=Lq，允许观测模型偏差 |
| `observerCfg.Model.Flux` | 0.035 | Wb | 观测模型永磁磁链 |
| `observerCfg.Model.PolePairs` | 4 | 计数 | 观测配置的极对数 |
| `observerCfg.InitialOmega` | 0 | 电角rad/s | 估速初值/方向初始化幅值；MRAS需不小于bootstrap下界，Kalman本App为0 |
| `observerCfg.InitialAngle` | 0 | 电角rad | 估计初始电角，非Plant真实角 |
| `observerCfg.InitialStd` | [1,1,500,0.5] | [A,A,电角rad/s,电角rad] | 四状态初始标准差，状态顺序iα、iβ、ωr、θr |
| `observerCfg.ProcessNoiseDensity` | [2,2,2000,1e-05] | [A²/s,A²/s,电角rad²/s³,电角rad²/s] | 四状态方差密度；乘Ts得到每步过程方差 |
| `observerCfg.MeasurementStd` | [0.002,0.002] | A RMS | 每次电流测量标准差假设；当前App未额外注入测量噪声 |
| `observerCfg.QualificationTime` | 0.02 | s | 连续满足观测资格的时间 |
| `observerCfg.MinOmega` | 30 | 电角rad/s | 最小资格电角速度 |
| `observerCfg.MinEmf` | 1 | V | 最小反电势幅值资格 |
| `observerCfg.MaxNIS` | 25 | 1 | 归一化创新平方的资格上限 |
| `observerCfg.MaxThetaStd` | 0.12 | 电角rad | 后验估角标准差资格上限，不是真实角误差上限 |
| `observerCfg.MaxOmegaStd` | 100 | 电角rad/s | 后验估速标准差资格上限 |
| `observerCfg.AngleRateTimeConstant` | 0.002 | s | 后验角变化率低通时间常数 |
| `observerCfg.MaxRateMismatch` | 60 | 电角rad/s | 后验角变化率与估速状态的允许差 |
| `observerCfg.MaxOmega` | 2000 | 电角rad/s | 估速上界 |
| `observerCfg.MaxInputCurrent` | 100 | A | 观测输入电流保护界 |
| `observerCfg.MaxInputVoltage` | 1000 | V | 观测输入电压保护界 |
| `observerCfg.InitialVariance` | [1,1,250000,0.25] | 状态单位平方 | InitialStd逐项平方 |
| `observerCfg.ProcessVariance` | [0.0001,0.0001,0.1,5e-10] | 状态单位平方 | ProcessNoiseDensity乘Model.Ts |
| `observerCfg.MeasurementVariance` | [4e-06,4e-06] | A² | MeasurementStd逐项平方 |
| `observerCfg.QualificationSamples` | 400 | 拍 | 由QualificationTime/Ts派生的计数 |
| `observerCfg.AngleRateAlpha` | 0.024390243902439025 | 1 | 角变化率滤波派生系数 |
| `observerCfg.Settings` | 27项派生向量，见参数M和快照 | 逐项SI/计数 | 供库mask使用的派生配置向量，修改上游值后refresh |
| `observerCfg.Alpha` | 1 | 1 | UKF sigma点扩展参数 |
| `observerCfg.Beta` | 2 | 1 | UKF先验分布协方差权重修正参数 |
| `observerCfg.Kappa` | 0 | 1 | UKF辅助扩展参数 |
| `observerCfg.StateScales` | [1,1,100,1] | [A,A,电角rad/s,电角rad] | 数值归一化状态尺度，不改真实物理单位 |
| `observerCfg.InitialJitter` | 1e-12 | 归一化协方差 | 归一化协方差分解的首次修复量 |
| `observerCfg.MaximumJitter` | 1e-08 | 归一化协方差 | 归一化协方差最大修复量 |
| `observerCfg.MaximumJitterAttempts` | 5 | 次 | 有界修复尝试次数 |
| `observerCfg.MinimumAngleResultant` | 1e-06 | 1 | 圆周平均合向量最小模长 |
| `observerCfg.MaximumSigmaAngleDeviation` | 1.5697963267948967 | 电角rad | sigma角相对均角最大包角偏差 |
| `observerCfg.UnscentedSettings` | 39项派生向量，见参数M和快照 | 逐项SI/计数 | UKF派生配置向量 |
| `observerCfg.SigmaScale` | 4 | 1 | n+λ，当前4 |
| `observerCfg.MeanWeights` | [0,0.125,0.125,0.125,0.125,0.125,0.125,0.125,0.125] | 1 | 9个sigma点均值权重 |
| `observerCfg.CovarianceWeights` | [2,0.125,0.125,0.125,0.125,0.125,0.125,0.125,0.125] | 1 | 9个sigma点协方差权重 |

### SIGMOID观测配置

`extensionCfg.Kind="sigmoid"`匹配`SigmoidSensorlessFOC.slx`，输入选择符不进入观测数值内核。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `observerCfg.Ts` | 5e-05 | s | 观测更新周期 |
| `observerCfg.Rs` | 0.5 | Ω | 观测模型电阻，允许与真实电机独立覆盖 |
| `observerCfg.L` | 0.001 | H | 局部SPMSM公共电感ℓ_sp；名义等于Ld=Lq，允许观测模型偏差 |
| `observerCfg.Flux` | 0.035 | Wb | 观测模型永磁磁链 |
| `observerCfg.PolePairs` | 4 | 计数 | 观测配置的极对数 |
| `observerCfg.SlidingGain` | 60 | V | sigmoid每轴注入的饱和幅值 |
| `observerCfg.Slope` | 0.6 | 1/A | sigmoid指数斜率；tanh内部使用Slope/2 |
| `observerCfg.MinEmf` | 1 | V | 最小反电势幅值资格 |
| `observerCfg.MinOmega` | 30 | 电角rad/s | 最小资格电角速度 |
| `observerCfg.MaxOmega` | 800 | 电角rad/s | 估速上界 |
| `observerCfg.MaxResidual` | 2 | A | sigmoid当前电流残差范数资格上限 |
| `observerCfg.MaxVoltage` | 200 | V | sigmoid输入电压保护界 |
| `observerCfg.MaxCurrent` | 20 | A | sigmoid输入电流保护界 |
| `observerCfg.MaxEstimate` | 40 | A | sigmoid估计电流保护界 |
| `observerCfg.A` | 0.9753099120283326 | 1 | 局部a_i=exp(-Rs Ts/ℓ_sp)，R-L记忆系数 |
| `observerCfg.B` | 0.049380175943334666 | A/V | 局部b_i=(1-a_i)/Rs，R-L输入系数；不是原书黏性B |
| `observerCfg.MaximumInjectionSlope` | 18 | V/A | SlidingGain×Slope/2，小信号最大注入斜率 |
| `observerCfg.LocalErrorPole` | 0.08646674504830865 | 1 | a_i-b_i×MaximumInjectionSlope，局部离散误差极点 |
| `observerCfg.Settings` | [0.9753099120283326,0.049380175943334666,60,0.6,200,20,40] | 逐项SI/计数 | 供库mask使用的派生配置向量，修改上游值后refresh |

#### sigmoid专用PLL

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `pllCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `pllCfg.NaturalFrequency` | 40 | Hz | 名义自然频率 |
| `pllCfg.Damping` | 0.707 | 1 | 阻尼比 |
| `pllCfg.Kp` | 355.3769609740774 | 1/s | 比例增益 |
| `pllCfg.Ki` | 63165.46816697189 | 1/s² | 积分增益 |
| `pllCfg.Kaw` | 502.6548245743669 | 1/s | 抗饱和回算增益 |
| `pllCfg.OmegaMax` | 1500 | 电角rad/s | PLL电角速度限制 |
| `pllCfg.MinMagnitude` | 1 | V | PLL输入EMF最小幅值 |
| `pllCfg.LockError` | 0.12 | 电角rad | PLL锁定相位误差界 |
| `pllCfg.LockSamples` | 100 | 拍 | PLL连续锁定计数 |
| `pllCfg.Theta0` | 0 | 电角rad | 软件启动/PLL初始电角度 |
| `pllCfg.Omega0` | 0 | 电角rad/s | PLL初始电角速度 |


## 输入信号

根图无外部Inport；From Workspace消费七列testStim（Structure With Time）。[运行方法](../build_process/EXTENSION_USAGE.md)说明修改/覆盖。

| 名称/列 | 单位 | 类型或初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|---|
| speed_reference / 1 | 机械rad/s | double，0→80，事件0.05s | stimulus→Controller | 受速度/斜率限制后进入转矩速度PI |
| load_torque / 2 | N·m | double，0→0.1，事件0.9s | stimulus→Plant | 从物理电磁转矩减去的外负载 |
| enable / 3 | 0/1 | double，1 | stimulus→StartInterlock | 请求，不直接等同门极许可 |
| reset / 4 | 0/1 | double，0 | 控制/观测/互锁 | 清控制状态，物理电机状态继续推进 |
| direction / 5 | ±1 | double，+1 | 控制/观测/互锁 | 启动方向先验；变化撤销许可 |
| observer_enable / 6 | 0/1 | double，1 | ObserverEnabled | 初次观察/运行估算使能 |
| bus_voltage / 7 | V | 正有限double，48 | Plant、分配器、调制共用 | fwCfg.BusTimes/BusValues生成分段保持实际母线 |

原三份App六列格式不能直接用于这四份App。50μs输入保持，物理桥5μs；速度PI1ms。

## 过程变量

| 名称 | 单位 | 类型或初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|---|
| 物理电流/转速/位置 | A、机械rad/s、机械rad | pmsmCfg.Id0/Iq0/Speed0/Position0 | Plant/Motor | 关断续流/自然机械推进，控制复位不清零 |
| MRAS状态 | 逐项SI/计数 | 库21项状态 | Observer/Estimator | 先前实测dq电流/电压、残差、相位、速度PI等；输出诊断约一拍旧 |
| EKF/UKF保持量 | 逐项SI/计数 | 库28项保持量 | Observer/Estimator | 4先验状态、完整4×4协方差与资格/历史/故障；本拍校正后输出 |
| sigmoid估计电流/方向/故障 | A、方向、代码 | 0 | Observer/Estimator | 当前误差产生平滑注入，精确R-L离散式推进下一电流 |
| terminal_voltage_magnitude | V | 当前测量 | Observer/TerminalVoltageMagnitude | 实际端电压Clarke后模长；互锁使用，非估速×磁链 |
| WarmCount/PermitState/PreviousDirection | 拍、boolean、±1 | 0/false/Direction | StartInterlock | 连续50ms观察且端电压≤0.25V才允许对齐；许可锁存后由Handover处理失锁 |
| PI积分及坐标历史 | V、N·m、电角rad | 0 | Controller库链接 | 坐标状态转移、对齐跟踪、同命令时刻电压残差与分配转矩回算 |
| id_fw | A | 0 | CurrentAllocator | 本批FwEnable=0，保持关闭；真实d电流可能因估角误差略偏0 |

观测器内部状态逐项顺序仍在所属lib参数页维护：[MRAS](../../../../lib/观测器/模型参考自适应/parameter/README.md)、[EKF](../../../../lib/观测器/扩展卡尔曼/parameter/README.md)、[UKF](../../../../lib/观测器/无迹卡尔曼/parameter/README.md)、[sigmoid](../../../../lib/观测器/滑模/parameter/SIGMOID_PARAMETERS.md)。App的导出日志与原始lib Test日志列不同。

## 输出信号

六组日志都由`record.<组>.time/trace/columns`解析。Plant5μs，其余50μs；慢速PI量显示为保持值。下表按实际Mux次序，矢量元素保持端口顺序，均double。Kalman协方差16列按MATLAB的P(:)列优先展开，状态顺序为iα/iβ/ωr/θr；Pij单位是状态i/j单位的乘积，不能按16个同单位量解释。

### 共同plant_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1–2 | `current_ab` | A | `#Motor.y1` | 记录此端口当前值；向量依元素顺序 |
| 3–5 | `phase_current` | A | `#Motor.y2` | 记录此端口当前值；向量依元素顺序 |
| 6–8 | `phase_voltage` | V | `#Motor.y3` | 记录此端口当前值；向量依元素顺序 |
| 9–10 | `voltage_ab` | V | `#Motor.y4` | 记录此端口当前值；向量依元素顺序 |
| 11 | `speed_mechanical` | mechanical rad/s | `#Motor.y5` | 记录此端口当前值；向量依元素顺序 |
| 12 | `theta_e` | electrical rad | `#Motor.y6` | 记录此端口当前值；向量依元素顺序 |
| 13 | `torque` | N*m | `#Motor.y7` | 记录此端口当前值；向量依元素顺序 |
| 14 | `dc_current` | A | `#Motor.y8` | 记录此端口当前值；向量依元素顺序 |
| 15–17 | `diode_states` | -1/0/+1 | `#Motor.y9` | 记录此端口当前值；向量依元素顺序 |
| 18 | `magnetic_energy` | J | `#Motor.y10` | 记录此端口当前值；向量依元素顺序 |
| 19 | `kinetic_energy` | J | `#Motor.y11` | 记录此端口当前值；向量依元素顺序 |
| 20 | `bridge_loss` | W | `#Motor.y12` | 记录此端口当前值；向量依元素顺序 |
| 21 | `equation_residual` | V | `#Motor.y13` | 记录此端口当前值；向量依元素顺序 |
| 22–24 | `next_phase_current` | A | `#Motor.y14` | 记录此端口当前值；向量依元素顺序 |
| 25 | `neutral_voltage` | V | `#Motor.y15` | 记录此端口当前值；向量依元素顺序 |
| 26–28 | `pole_voltage` | V | `#Motor.y16` | 记录此端口当前值；向量依元素顺序 |
| 29 | `load_torque` | N*m | `#load_torque.y1` | 记录此端口当前值；向量依元素顺序 |
| 30 | `bus_voltage` | V | `#bus_voltage.y1` | 记录此端口当前值；向量依元素顺序 |
| 31 | `bridge_mode` | 0/1/2 | `#mode.y1` | 记录此端口当前值；向量依元素顺序 |
| 32–34 | `duty` | 1 | `#duty.y1` | 记录此端口当前值；向量依元素顺序 |
| 35 | `id_true` | A | `#RotorPark.y1` | 记录此端口当前值；向量依元素顺序 |
| 36 | `iq_true` | A | `#RotorPark.y2` | 记录此端口当前值；向量依元素顺序 |

### 共同controller_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1–2 | `control_current` | A | `#ControlCurrent.y1` | 记录此端口当前值；向量依元素顺序 |
| 3 | `speed_reference` | mechanical rad/s | `#SpeedReferenceSlew.y1` | 记录此端口当前值；向量依元素顺序 |
| 4 | `speed_error` | mechanical rad/s | `#SpeedErrorSample.y1` | 记录此端口当前值；向量依元素顺序 |
| 5 | `torque_request` | N*m | `#SpeedPI.y1` | 记录此端口当前值；向量依元素顺序 |
| 6 | `torque_allocated` | N*m | `#CurrentAllocator.y3` | 记录此端口当前值；向量依元素顺序 |
| 7 | `torque_estimated` | N*m | `#EstimatedTorqueSample.y1` | 记录此端口当前值；向量依元素顺序 |
| 8 | `integral_torque` | N*m | `#SpeedPI.y2` | 记录此端口当前值；向量依元素顺序 |
| 9 | `iq_closed` | A | `#CurrentAllocator.y2` | 记录此端口当前值；向量依元素顺序 |
| 10–11 | `reference` | A | `#ReferenceBlend.y1` | 记录此端口当前值；向量依元素顺序 |
| 12–13 | `voltage_pi` | V | `#CurrentPI.y1` | 记录此端口当前值；向量依元素顺序 |
| 14–15 | `integral_base` | V | `#CurrentPI.y2` | 记录此端口当前值；向量依元素顺序 |
| 16–17 | `integral_state` | V | `#CurrentPI.y3` | 记录此端口当前值；向量依元素顺序 |
| 18–19 | `voltage_residual` | V | `#voltage_residual.y1` | 记录此端口当前值；向量依元素顺序 |
| 20 | `theta_start` | electrical rad | `#Startup.y1` | 记录此端口当前值；向量依元素顺序 |
| 21 | `omega_start` | electrical rad/s | `#Startup.y2` | 记录此端口当前值；向量依元素顺序 |
| 22 | `id_start` | A | `#Startup.y3` | 记录此端口当前值；向量依元素顺序 |
| 23 | `iq_start` | A | `#Startup.y4` | 记录此端口当前值；向量依元素顺序 |
| 24 | `ready` | 1 | `#Startup.y5` | 记录此端口当前值；向量依元素顺序 |
| 25 | `startup_mode` | 1 | `#Startup.y6` | 记录此端口当前值；向量依元素顺序 |
| 26 | `startup_fault` | 1 | `#Startup.y7` | 记录此端口当前值；向量依元素顺序 |
| 27 | `startup_elapsed` | s | `#Startup.y8` | 记录此端口当前值；向量依元素顺序 |
| 28 | `theta_used` | electrical rad | `#Handover.y1` | 记录此端口当前值；向量依元素顺序 |
| 29 | `omega_base` | electrical rad/s | `#Handover.y2` | 记录此端口当前值；向量依元素顺序 |
| 30 | `omega_frame` | electrical rad/s | `#Handover.y3` | 记录此端口当前值；向量依元素顺序 |
| 31 | `beta` | 1 | `#Handover.y4` | 记录此端口当前值；向量依元素顺序 |
| 32 | `handover_mode` | 1 | `#Handover.y5` | 记录此端口当前值；向量依元素顺序 |
| 33 | `handover_fault` | 1 | `#Handover.y6` | 记录此端口当前值；向量依元素顺序 |
| 34 | `acquired` | 1 | `#Handover.y7` | 记录此端口当前值；向量依元素顺序 |
| 35 | `run` | 1 | `#Handover.y8` | 记录此端口当前值；向量依元素顺序 |
| 36 | `qualification_count` | samples | `#Handover.y9` | 记录此端口当前值；向量依元素顺序 |
| 37 | `loss_count` | samples | `#Handover.y10` | 记录此端口当前值；向量依元素顺序 |
| 38 | `phase_offset` | rad | `#Handover.y11` | 记录此端口当前值；向量依元素顺序 |
| 39 | `delta_extra` | rad | `#ExtraAngle.y1` | 记录此端口当前值；向量依元素顺序 |
| 40 | `track` | 1 | `#TrackDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 41 | `auto_sampled` | 1 | `#AutoDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 42 | `voltage_alignment` | 1 | `#VoltageAlignDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 43–44 | `voltage_selected` | V | `#VoltageSelected.y1` | 记录此端口当前值；向量依元素顺序 |
| 45–46 | `pi_residual` | V | `#PIResidualUsed.y1` | 记录此端口当前值；向量依元素顺序 |

### 共同allocation_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1 | `id_reference` | A | `#CurrentAllocator.y1` | 记录此端口当前值；向量依元素顺序 |
| 2 | `iq_reference` | A | `#CurrentAllocator.y2` | 记录此端口当前值；向量依元素顺序 |
| 3 | `allocated_torque` | N*m | `#CurrentAllocator.y3` | 记录此端口当前值；向量依元素顺序 |
| 4 | `id_mtpa` | A | `#CurrentAllocator.y4` | 记录此端口当前值；向量依元素顺序 |
| 5 | `iq_mtpa` | A | `#CurrentAllocator.y5` | 记录此端口当前值；向量依元素顺序 |
| 6 | `id_fw` | A | `#CurrentAllocator.y6` | 记录此端口当前值；向量依元素顺序 |
| 7 | `filtered_voltage` | V | `#CurrentAllocator.y7` | 记录此端口当前值；向量依元素顺序 |
| 8 | `voltage_available` | V | `#CurrentAllocator.y8` | 记录此端口当前值；向量依元素顺序 |
| 9 | `predicted_voltage` | V | `#CurrentAllocator.y9` | 记录此端口当前值；向量依元素顺序 |
| 10 | `current_margin` | A | `#CurrentAllocator.y10` | 记录此端口当前值；向量依元素顺序 |
| 11 | `voltage_margin` | V | `#CurrentAllocator.y11` | 记录此端口当前值；向量依元素顺序 |
| 12 | `torque_residual` | N*m | `#CurrentAllocator.y12` | 记录此端口当前值；向量依元素顺序 |
| 13 | `current_limited` | 1 | `#CurrentLimitFlagDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 14 | `voltage_limited` | 1 | `#VoltageLimitFlagDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 15 | `feasible` | 1 | `#FeasibleFlagDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 16 | `fw_active` | 1 | `#WeakeningFlagDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 17 | `voltage_error` | V | `#CurrentAllocator.y17` | 记录此端口当前值；向量依元素顺序 |
| 18 | `model_voltage_demand` | V | `#CurrentAllocator.y18` | 记录此端口当前值；向量依元素顺序 |
| 19 | `effective_voltage_demand` | V | `#CurrentAllocator.y19` | 记录此端口当前值；向量依元素顺序 |
| 20 | `torque_request` | N*m | `#SpeedPI.y1` | 记录此端口当前值；向量依元素顺序 |
| 21 | `omega_e` | electrical rad/s | `#Handover.y2` | 记录此端口当前值；向量依元素顺序 |
| 22 | `bus_voltage` | V | `#bus_voltage.y1` | 记录此端口当前值；向量依元素顺序 |
| 23 | `voltage_demand_prev` | V | `#VoltageDemandPrevious.y1` | 记录此端口当前值；向量依元素顺序 |
| 24 | `drive_enable` | 1 | `#Handover.y8` | 记录此端口当前值；向量依元素顺序 |
| 25 | `reset` | 1 | `#reset.y1` | 记录此端口当前值；向量依元素顺序 |

### 共同actuation_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1–7 | `stimulus` | mixed | `#stimulus.y1` | 记录此端口当前值；向量依元素顺序 |
| 8–9 | `voltage_request` | V | `#Controller.y1` | 记录此端口当前值；向量依元素顺序 |
| 10 | `theta_control` | electrical rad | `#Controller.y2` | 记录此端口当前值；向量依元素顺序 |
| 11–13 | `phase_voltage` | V | `#VoltageStage.y6` | 记录此端口当前值；向量依元素顺序 |
| 14–16 | `duty_command` | 1 | `#VoltageStage.y1` | 记录此端口当前值；向量依元素顺序 |
| 17–19 | `duty_applied` | 1 | `#VoltageStage.y2` | 记录此端口当前值；向量依元素顺序 |
| 20 | `voltage_scale` | 1 | `#VoltageStage.y3` | 记录此端口当前值；向量依元素顺序 |
| 21–22 | `voltage_residual` | V | `#VoltageStage.y4` | 记录此端口当前值；向量依元素顺序 |
| 23–25 | `measured_phase_current` | A | `#Measurement.y2` | 记录此端口当前值；向量依元素顺序 |
| 26–27 | `measured_current_ab` | A | `#Measurement.y1` | 记录此端口当前值；向量依元素顺序 |

### 共同guard_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1 | `request_enable` | 1 | `#request_enable.y1` | 记录此端口当前值；向量依元素顺序 |
| 2 | `reset` | 1 | `#reset.y1` | 记录此端口当前值；向量依元素顺序 |
| 3 | `observer_enable` | 1 | `#observer_enable.y1` | 记录此端口当前值；向量依元素顺序 |
| 4 | `terminal_voltage_magnitude` | V | `#voltage_magnitude.y1` | 记录此端口当前值；向量依元素顺序 |
| 5 | `direction` | -1/+1 | `#direction.y1` | 记录此端口当前值；向量依元素顺序 |
| 6 | `warm_count` | samples | `#WarmCount.y1` | 记录此端口当前值；向量依元素顺序 |
| 7 | `permit` | 1 | `#PermitSelected.y1` | 记录此端口当前值；向量依元素顺序 |
| 8 | `qualified` | 1 | `#QualifiedDouble.y1` | 记录此端口当前值；向量依元素顺序 |
| 9 | `direction_changed` | 1 | `#DirectionChangedDouble.y1` | 记录此端口当前值；向量依元素顺序 |

### MRAS observer_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1 | `theta_hat` | electrical rad | `#Estimator.y1` | 记录此端口当前值；向量依元素顺序 |
| 2 | `omega_hat` | electrical rad/s | `#Estimator.y2` | 记录此端口当前值；向量依元素顺序 |
| 3 | `valid` | 1 | `#Estimator.y3` | 记录此端口当前值；向量依元素顺序 |
| 4 | `predicted_id` | A | `#Estimator.y4` | 记录此端口当前值；向量依元素顺序 |
| 5 | `predicted_iq` | A | `#Estimator.y5` | 记录此端口当前值；向量依元素顺序 |
| 6 | `measured_id` | A | `#Estimator.y6` | 记录此端口当前值；向量依元素顺序 |
| 7 | `measured_iq` | A | `#Estimator.y7` | 记录此端口当前值；向量依元素顺序 |
| 8 | `residual_d` | A | `#Estimator.y8` | 记录此端口当前值；向量依元素顺序 |
| 9 | `residual_q` | A | `#Estimator.y9` | 记录此端口当前值；向量依元素顺序 |
| 10 | `normalized_d` | 1 | `#Estimator.y10` | 记录此端口当前值；向量依元素顺序 |
| 11 | `normalized_q` | 1 | `#Estimator.y11` | 记录此端口当前值；向量依元素顺序 |
| 12 | `emf_magnitude` | V | `#Estimator.y12` | 记录此端口当前值；向量依元素顺序 |
| 13 | `qualification_count` | samples | `#Estimator.y13` | 记录此端口当前值；向量依元素顺序 |
| 14 | `speed_integral` | electrical rad/s | `#Estimator.y14` | 记录此端口当前值；向量依元素顺序 |
| 15 | `fault` | code | `#Estimator.y15` | 记录此端口当前值；向量依元素顺序 |
| 16 | `normalization_denominator` | A | `#Estimator.y16` | 记录此端口当前值；向量依元素顺序 |
| 17–18 | `current_ab` | A | `#current_ab.y1` | 记录此端口当前值；向量依元素顺序 |
| 19–20 | `observer_voltage` | V | `#VoltageAge.y1` | 记录此端口当前值；向量依元素顺序 |
| 21 | `observer_residual` | A | `#ResidualNorm.y1` | 记录此端口当前值；向量依元素顺序 |
| 22 | `enable` | 1 | `#enable.y1` | 记录此端口当前值；向量依元素顺序 |
| 23 | `reset` | 1 | `#reset.y1` | 记录此端口当前值；向量依元素顺序 |
| 24 | `direction` | -1/+1 | `#direction.y1` | 记录此端口当前值；向量依元素顺序 |
| 25 | `terminal_voltage_magnitude` | V | `#TerminalVoltageMagnitude.y1` | 记录此端口当前值；向量依元素顺序 |

### EKF/UKF observer_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1 | `theta_hat` | electrical rad | `#Estimator.y1` | 记录此端口当前值；向量依元素顺序 |
| 2 | `omega_hat` | electrical rad/s | `#Estimator.y2` | 记录此端口当前值；向量依元素顺序 |
| 3 | `valid` | 1 | `#Estimator.y3` | 记录此端口当前值；向量依元素顺序 |
| 4 | `i_hat_alpha` | A | `#Estimator.y4` | 记录此端口当前值；向量依元素顺序 |
| 5 | `i_hat_beta` | A | `#Estimator.y5` | 记录此端口当前值；向量依元素顺序 |
| 6 | `innovation_alpha` | A | `#Estimator.y6` | 记录此端口当前值；向量依元素顺序 |
| 7 | `innovation_beta` | A | `#Estimator.y7` | 记录此端口当前值；向量依元素顺序 |
| 8 | `normalized_innovation` | 1 | `#Estimator.y8` | 记录此端口当前值；向量依元素顺序 |
| 9 | `theta_std` | electrical rad | `#Estimator.y9` | 记录此端口当前值；向量依元素顺序 |
| 10 | `omega_std` | electrical rad/s | `#Estimator.y10` | 记录此端口当前值；向量依元素顺序 |
| 11 | `angle_rate` | electrical rad/s | `#Estimator.y11` | 记录此端口当前值；向量依元素顺序 |
| 12 | `rate_mismatch` | electrical rad/s | `#Estimator.y12` | 记录此端口当前值；向量依元素顺序 |
| 13 | `qualification_count` | samples | `#Estimator.y13` | 记录此端口当前值；向量依元素顺序 |
| 14 | `fault` | code | `#Estimator.y14` | 记录此端口当前值；向量依元素顺序 |
| 15 | `variance_i_alpha` | A^2 | `#Estimator.y15` | 记录此端口当前值；向量依元素顺序 |
| 16 | `variance_i_beta` | A^2 | `#Estimator.y16` | 记录此端口当前值；向量依元素顺序 |
| 17 | `variance_omega` | (electrical rad/s)^2 | `#Estimator.y17` | 记录此端口当前值；向量依元素顺序 |
| 18 | `variance_theta` | (electrical rad)^2 | `#Estimator.y18` | 记录此端口当前值；向量依元素顺序 |
| 19 | `gain_theta_alpha` | rad/A | `#Estimator.y19` | 记录此端口当前值；向量依元素顺序 |
| 20 | `gain_theta_beta` | rad/A | `#Estimator.y20` | 记录此端口当前值；向量依元素顺序 |
| 21 | `gain_omega_alpha` | rad/(s*A) | `#Estimator.y21` | 记录此端口当前值；向量依元素顺序 |
| 22 | `gain_omega_beta` | rad/(s*A) | `#Estimator.y22` | 记录此端口当前值；向量依元素顺序 |
| 23 | `emf_magnitude` | V | `#Estimator.y23` | 记录此端口当前值；向量依元素顺序 |
| 24 | `numeric_repairs` | count | `#Estimator.y24` | 记录此端口当前值；向量依元素顺序 |
| 25–40 | `covariance` | mixed covariance | `#Estimator.y25` | 记录此端口当前值；向量依元素顺序 |
| 41–42 | `current_ab` | A | `#current_ab.y1` | 记录此端口当前值；向量依元素顺序 |
| 43–44 | `observer_voltage` | V | `#VoltageAge.y1` | 记录此端口当前值；向量依元素顺序 |
| 45 | `observer_residual` | A | `#ResidualNorm.y1` | 记录此端口当前值；向量依元素顺序 |
| 46 | `enable` | 1 | `#enable.y1` | 记录此端口当前值；向量依元素顺序 |
| 47 | `reset` | 1 | `#reset.y1` | 记录此端口当前值；向量依元素顺序 |
| 48 | `direction` | -1/+1 | `#direction.y1` | 记录此端口当前值；向量依元素顺序 |
| 49 | `terminal_voltage_magnitude` | V | `#TerminalVoltageMagnitude.y1` | 记录此端口当前值；向量依元素顺序 |

### SIGMOID observer_trace

| 列 | 名称 | 单位 | 来源端口 | 计算或用途 |
|---|---|---|---|---|
| 1 | `theta_hat` | electrical rad | `#Estimator.y1` | 记录此端口当前值；向量依元素顺序 |
| 2 | `omega_hat` | electrical rad/s | `#Estimator.y2` | 记录此端口当前值；向量依元素顺序 |
| 3 | `valid` | 1 | `#Estimator.y3` | 记录此端口当前值；向量依元素顺序 |
| 4 | `emf_alpha` | V | `#Estimator.y4` | 记录此端口当前值；向量依元素顺序 |
| 5 | `emf_beta` | V | `#Estimator.y5` | 记录此端口当前值；向量依元素顺序 |
| 6 | `i_hat_alpha` | A | `#Estimator.y6` | 记录此端口当前值；向量依元素顺序 |
| 7 | `i_hat_beta` | A | `#Estimator.y7` | 记录此端口当前值；向量依元素顺序 |
| 8 | `residual_alpha` | A | `#Estimator.y8` | 记录此端口当前值；向量依元素顺序 |
| 9 | `residual_beta` | A | `#Estimator.y9` | 记录此端口当前值；向量依元素顺序 |
| 10 | `phase_measured` | rad | `#Estimator.y10` | 记录此端口当前值；向量依元素顺序 |
| 11 | `emf_magnitude` | V | `#Estimator.y11` | 记录此端口当前值；向量依元素顺序 |
| 12 | `phase_error` | rad | `#Estimator.y12` | 记录此端口当前值；向量依元素顺序 |
| 13 | `fault` | code | `#Estimator.y13` | 记录此端口当前值；向量依元素顺序 |
| 14 | `residual_norm` | A | `#Estimator.y14` | 记录此端口当前值；向量依元素顺序 |
| 15–16 | `current_ab` | A | `#current_ab.y1` | 记录此端口当前值；向量依元素顺序 |
| 17–18 | `observer_voltage` | V | `#VoltageAge.y1` | 记录此端口当前值；向量依元素顺序 |
| 19 | `observer_residual` | A | `#ResidualNorm.y1` | 记录此端口当前值；向量依元素顺序 |
| 20 | `enable` | 1 | `#enable.y1` | 记录此端口当前值；向量依元素顺序 |
| 21 | `reset` | 1 | `#reset.y1` | 记录此端口当前值；向量依元素顺序 |
| 22 | `direction` | -1/+1 | `#direction.y1` | 记录此端口当前值；向量依元素顺序 |
| 23 | `terminal_voltage_magnitude` | V | `#TerminalVoltageMagnitude.y1` | 记录此端口当前值；向量依元素顺序 |

## Scope 通道

共同24组Scope只登记一次，并逐模型核对完全相同；Observer内按MRAS、EKF/UKF、sigmoid分别列出。原生编译总数依次30/32/32/30，每模型20个库链接。表中通道号是Scope显示顺序，不是六组日志的全局列号。Scope继承输入时序，慢量保持；物理/电流/速度周期见前文。

### 四App共同Scope

#### Controller/AllocationFlagsScope：4通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `current_limited` | `Controller/CurrentLimitFlagDouble.y1` | 1，double | current_limited实际值；矢量按abc或dq顺序 |
| 2 | `voltage_limited` | `Controller/VoltageLimitFlagDouble.y1` | 1，double | voltage_limited实际值；矢量按abc或dq顺序 |
| 3 | `feasible` | `Controller/FeasibleFlagDouble.y1` | 1，double | feasible实际值；矢量按abc或dq顺序 |
| 4 | `fw_active` | `Controller/WeakeningFlagDouble.y1` | 1，double | fw_active实际值；矢量按abc或dq顺序 |

#### Controller/AllocationVoltageScope：6通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `filtered_voltage` | `Controller/CurrentAllocator.y7` | V，double | filtered_voltage实际值；矢量按abc或dq顺序 |
| 2 | `voltage_available` | `Controller/CurrentAllocator.y8` | V，double | voltage_available实际值；矢量按abc或dq顺序 |
| 3 | `predicted_voltage` | `Controller/CurrentAllocator.y9` | V，double | predicted_voltage实际值；矢量按abc或dq顺序 |
| 4 | `voltage_margin` | `Controller/CurrentAllocator.y11` | V，double | voltage_margin实际值；矢量按abc或dq顺序 |
| 5 | `model_voltage_demand` | `Controller/CurrentAllocator.y18` | V，double | model_voltage_demand实际值；矢量按abc或dq顺序 |
| 6 | `effective_voltage_demand` | `Controller/CurrentAllocator.y19` | V，double | effective_voltage_demand实际值；矢量按abc或dq顺序 |

#### Controller/AngleScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_start` | `Controller/Startup.y1` | electrical rad，double | theta_start实际值；矢量按abc或dq顺序 |
| 2 | `theta_hat` | `Controller/theta_hat.y1` | 电角rad，double | theta_hat实际值；矢量按abc或dq顺序 |
| 3 | `theta_used` | `Controller/Handover.y1` | electrical rad，double | theta_used实际值；矢量按abc或dq顺序 |

#### Controller/CurrentAllocationScope：5通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `id_mtpa` | `Controller/CurrentAllocator.y4` | A，double | id_mtpa实际值；矢量按abc或dq顺序 |
| 2 | `iq_mtpa` | `Controller/CurrentAllocator.y5` | A，double | iq_mtpa实际值；矢量按abc或dq顺序 |
| 3 | `id_reference` | `Controller/CurrentAllocator.y1` | A，double | id_reference实际值；矢量按abc或dq顺序 |
| 4 | `iq_reference` | `Controller/CurrentAllocator.y2` | A，double | iq_reference实际值；矢量按abc或dq顺序 |
| 5 | `id_fw` | `Controller/CurrentAllocator.y6` | A，double | id_fw实际值；矢量按abc或dq顺序 |

#### Controller/CurrentScope：4通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `reference` | `Controller/ReferenceBlend.y1` | A，double | reference实际值；矢量按abc或dq顺序 |
| 3 | `id_control_measured` | `Controller/ControlPark.y1` | A，double | 按控制角Park的d电流，区别于物理真角dq |
| 4 | `iq_control_measured` | `Controller/ControlPark.y2` | A，double | 按控制角Park的q电流，区别于物理真角dq |

#### Controller/ExtraAngleScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `delta_extra` | `Controller/ExtraAngle.y1` | rad，double | delta_extra实际值；矢量按abc或dq顺序 |

#### Controller/FrameSpeedScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_start` | `Controller/Startup.y2` | electrical rad/s，double | omega_start实际值；矢量按abc或dq顺序 |
| 2 | `omega_e` | `Controller/Handover.y2` | electrical rad/s，double | omega_e实际值；矢量按abc或dq顺序 |
| 3 | `omega_frame` | `Controller/Handover.y3` | electrical rad/s，double | omega_frame实际值；矢量按abc或dq顺序 |

#### Controller/SpeedLoopScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `speed_reference` | `Controller/SpeedReferenceSlew.y1` | mechanical rad/s，double | speed_reference实际值；矢量按abc或dq顺序 |
| 2 | `omega_hat/P` | `Controller/MechanicalEstimate.y1` | 机械rad/s，double | 参与控制的估计机械速度 |

#### Controller/StateScope：5通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `startup_mode` | `Controller/Startup.y6` | 1，double | startup_mode实际值；矢量按abc或dq顺序 |
| 2 | `startup_fault` | `Controller/Startup.y7` | 1，double | startup_fault实际值；矢量按abc或dq顺序 |
| 3 | `handover_mode` | `Controller/Handover.y5` | 1，double | handover_mode实际值；矢量按abc或dq顺序 |
| 4 | `handover_fault` | `Controller/Handover.y6` | 1，double | handover_fault实际值；矢量按abc或dq顺序 |
| 5 | `drive_enable` | `Controller/Handover.y8` | 1，double | drive_enable实际值；矢量按abc或dq顺序 |

#### Controller/TorqueLoopScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `torque_request` | `Controller/SpeedPI.y1` | N*m，double | torque_request实际值；矢量按abc或dq顺序 |
| 2 | `allocated_torque` | `Controller/CurrentAllocator.y3` | N*m，double | allocated_torque实际值；矢量按abc或dq顺序 |
| 3 | `torque_estimated` | `Controller/EstimatedTorqueSample.y1` | N*m，double | torque_estimated实际值；矢量按abc或dq顺序 |

#### Controller/TransitionScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `beta` | `Controller/Handover.y4` | 1，double | beta实际值；矢量按abc或dq顺序 |
| 2 | `track` | `Controller/TrackDouble.y1` | 1，double | track实际值；矢量按abc或dq顺序 |

#### Controller/VoltageScope：4通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `voltage_pi` | `Controller/CurrentPI.y1` | V，double | voltage_pi实际值；矢量按abc或dq顺序 |
| 3–4 | `voltage_residual` | `Controller/voltage_residual.y1` | V，double | voltage_residual实际值；矢量按abc或dq顺序 |

#### Plant/BridgeModeScope：4通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `bridge_mode` | `Plant/mode.y1` | 0/1/2，double | bridge_mode实际值；矢量按abc或dq顺序 |
| 2–4 | `diode_states` | `Plant/Motor.y9` | -1/0/+1，double | diode_states实际值；矢量按abc或dq顺序 |

#### Plant/BusCurrentScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `dc_current` | `Plant/Motor.y8` | A，double | dc_current实际值；矢量按abc或dq顺序 |

#### Plant/BusVoltageScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `bus_voltage` | `Plant/bus_voltage.y1` | V，double | bus_voltage实际值；矢量按abc或dq顺序 |

#### Plant/MechanicalSpeedScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `speed_mechanical` | `Plant/Motor.y5` | mechanical rad/s，double | 真实机械速度，仅物理/离线评价 |

#### Plant/TorqueScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `torque` | `Plant/Motor.y7` | N*m，double | torque实际值；矢量按abc或dq顺序 |
| 2 | `load_torque` | `Plant/load_torque.y1` | N*m，double | load_torque实际值；矢量按abc或dq顺序 |

#### Plant/TrueCurrentScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `id_true` | `Plant/RotorPark.y1` | A，double | id_true实际值；矢量按abc或dq顺序 |
| 2 | `iq_true` | `Plant/RotorPark.y2` | A，double | iq_true实际值；矢量按abc或dq顺序 |

#### StartInterlock/ObservationCountScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `warm_count` | `StartInterlock/WarmCount.y1` | samples，double | warm_count实际值；矢量按abc或dq顺序 |

#### StartInterlock/ObservedVoltageScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `terminal_voltage_magnitude` | `StartInterlock/voltage_magnitude.y1` | V，double | 实际端电压幅值；初次许可后允许随正常转速上升 |

#### StartInterlock/PermitScope：4通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `request_enable` | `StartInterlock/request_enable.y1` | 1，double | request_enable实际值；矢量按abc或dq顺序 |
| 2 | `permit` | `StartInterlock/PermitSelected.y1` | 1，double | permit实际值；矢量按abc或dq顺序 |
| 3 | `qualified` | `StartInterlock/QualifiedDouble.y1` | 1，double | qualified实际值；矢量按abc或dq顺序 |
| 4 | `direction_changed` | `StartInterlock/DirectionChangedDouble.y1` | 1，double | direction_changed实际值；矢量按abc或dq顺序 |

#### VoltageStage/ActualPhaseVoltageScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–3 | `actual_phase_voltage_abc` | `VoltageStage/actual_phase_voltage.y1` | V，double | actual_phase_voltage_abc实际值；矢量按abc或dq顺序 |

#### VoltageStage/DutyScope：6通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–3 | `duty_command_abc` | `VoltageStage/EnabledDuty.y1` | 1，double | duty_command_abc实际值；矢量按abc或dq顺序 |
| 4–6 | `duty_applied_abc` | `VoltageStage/TimingSelect.y1` | 1，double | duty_applied_abc实际值；矢量按abc或dq顺序 |

#### VoltageStage/VoltageResidualScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `command_voltage_residual_dq` | `VoltageStage/ConsistentResidual.y1` | V，double | command_voltage_residual_dq实际值；矢量按abc或dq顺序 |

### MRAS Observer

#### Observer/EstimateAngleScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_hat` | `Observer/Estimator.y1` | electrical rad，double | theta_hat实际值；矢量按abc或dq顺序 |

#### Observer/EstimateSpeedScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_hat` | `Observer/Estimator.y2` | electrical rad/s，double | omega_hat实际值；矢量按abc或dq顺序 |

#### Observer/NormalizedResidualScope：2通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `normalized_d` | `Observer/Estimator.y10` | 1，double | normalized_d实际值；矢量按abc或dq顺序 |
| 2 | `normalized_q` | `Observer/Estimator.y11` | 1，double | normalized_q实际值；矢量按abc或dq顺序 |

#### Observer/ResidualScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `residual_d` | `Observer/Estimator.y8` | A，double | residual_d实际值；矢量按abc或dq顺序 |
| 2 | `residual_q` | `Observer/Estimator.y9` | A，double | residual_q实际值；矢量按abc或dq顺序 |
| 3 | `observer_residual` | `Observer/ResidualNorm.y1` | A，double | observer_residual实际值；矢量按abc或dq顺序 |

#### Observer/TerminalVoltageScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `terminal_voltage_magnitude` | `Observer/TerminalVoltageMagnitude.y1` | V，double | 实际端电压幅值；初次许可后允许随正常转速上升 |

#### Observer/ValidityScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `valid` | `Observer/Estimator.y3` | 1，double | 库资格标志，上层另有持续资格与切换 |
| 2 | `enable` | `Observer/enable.y1` | 1，double | enable实际值；矢量按abc或dq顺序 |
| 3 | `reset` | `Observer/reset.y1` | 1，double | reset实际值；矢量按abc或dq顺序 |

### EKF/UKF Observer

#### Observer/AngleUncertaintyScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_std` | `Observer/Estimator.y9` | electrical rad，double | 后验角不确定度，非真实角误差；MaxThetaStd=0.12电角rad |

#### Observer/EstimateAngleScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_hat` | `Observer/Estimator.y1` | electrical rad，double | theta_hat实际值；矢量按abc或dq顺序 |

#### Observer/EstimateSpeedScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_hat` | `Observer/Estimator.y2` | electrical rad/s，double | omega_hat实际值；矢量按abc或dq顺序 |

#### Observer/NISScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `normalized_innovation` | `Observer/Estimator.y8` | 1，double | NIS=νᵀS⁻¹ν；默认MaxNIS=25 |

#### Observer/ResidualScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `innovation_alpha` | `Observer/Estimator.y6` | A，double | innovation_alpha实际值；矢量按abc或dq顺序 |
| 2 | `innovation_beta` | `Observer/Estimator.y7` | A，double | innovation_beta实际值；矢量按abc或dq顺序 |
| 3 | `observer_residual` | `Observer/ResidualNorm.y1` | A，double | observer_residual实际值；矢量按abc或dq顺序 |

#### Observer/SpeedUncertaintyScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_std` | `Observer/Estimator.y10` | electrical rad/s，double | 后验速度不确定度；MaxOmegaStd=100电角rad/s |

#### Observer/TerminalVoltageScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `terminal_voltage_magnitude` | `Observer/TerminalVoltageMagnitude.y1` | V，double | 实际端电压幅值；初次许可后允许随正常转速上升 |

#### Observer/ValidityScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `valid` | `Observer/Estimator.y3` | 1，double | 库资格标志，上层另有持续资格与切换 |
| 2 | `enable` | `Observer/enable.y1` | 1，double | enable实际值；矢量按abc或dq顺序 |
| 3 | `reset` | `Observer/reset.y1` | 1，double | reset实际值；矢量按abc或dq顺序 |

### SIGMOID Observer

#### Observer/EmfScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `emf_alpha` | `Observer/Estimator.y4` | V，double | emf_alpha实际值；矢量按abc或dq顺序 |
| 2 | `emf_beta` | `Observer/Estimator.y5` | V，double | emf_beta实际值；矢量按abc或dq顺序 |
| 3 | `emf_magnitude` | `Observer/Estimator.y11` | V，double | emf_magnitude实际值；矢量按abc或dq顺序 |

#### Observer/EstimateAngleScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_hat` | `Observer/Estimator.y1` | electrical rad，double | theta_hat实际值；矢量按abc或dq顺序 |

#### Observer/EstimateSpeedScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_hat` | `Observer/Estimator.y2` | electrical rad/s，double | omega_hat实际值；矢量按abc或dq顺序 |

#### Observer/ResidualScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `residual_alpha` | `Observer/Estimator.y8` | A，double | residual_alpha实际值；矢量按abc或dq顺序 |
| 2 | `residual_beta` | `Observer/Estimator.y9` | A，double | residual_beta实际值；矢量按abc或dq顺序 |
| 3 | `observer_residual` | `Observer/ResidualNorm.y1` | A，double | observer_residual实际值；矢量按abc或dq顺序 |

#### Observer/TerminalVoltageScope：1通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `terminal_voltage_magnitude` | `Observer/TerminalVoltageMagnitude.y1` | V，double | 实际端电压幅值；初次许可后允许随正常转速上升 |

#### Observer/ValidityScope：3通道

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `valid` | `Observer/Estimator.y3` | 1，double | 库资格标志，上层另有持续资格与切换 |
| 2 | `enable` | `Observer/enable.y1` | 1，double | enable实际值；矢量按abc或dq顺序 |
| 3 | `reset` | `Observer/reset.y1` | 1，double | reset实际值；矢量按abc或dq顺序 |

Handover模式4表示AUTO；其他启动/切换代码分别见[启动库](../../../../lib/无感启动/parameter/README.md)与[切换库](../../../../lib/无感切换/parameter/README.md)。桥请求0/1/2为关断/PWM/主动短路，本批App只使用0/1；支路代码见[桥参数](../../../../lib/永磁同步电机/parameter/BRIDGE_PARAMETERS.md)。这份通道表不能作为主动短路控制策略已验证的依据。

[运行与改参](../build_process/EXTENSION_USAGE.md) · [搭建](../build_process/EXTENSION_BUILD.md) · [40项波形分析](../waveform_analysis/EXTENSION_ANALYSIS.md) · [本模块公式](../docs/公式推导.md)
