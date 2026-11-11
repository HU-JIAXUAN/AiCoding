# 参数、信号与Scope

## 配置参数

本模块可执行入口为[sensorless_fw_parameters.m](sensorless_fw_parameters.m)。它组合共用库参数和EEMF App基线，再覆盖凸极电机、弱磁和真实母线工况；[refresh_sensorless_fw_parameters.m](refresh_sensorless_fw_parameters.m)生成MTPA表、配置向量、桥状态与互锁拍数。初始化命令为`initialize_sensorless_fw('SensorlessFieldWeakeningFOC')`；单次覆盖方法见[运行说明](../build_process/USAGE.md)。

以下默认值由实际参数入口的JSON快照逐项生成。派生项不要只改SLX常量；先改其上游物理值，再refresh。`motionCfg`除SpeedLimit/AccelerationLimit外的字段，以及deadtimeCfg、experimentCfg.UseInverter/LogTs、focCfg.CurrentMax/Kt是共用基线返回的兼容字段，不控制本App；下表明确标记。当前限流采用refCfg.CurrentMax，转矩估计采用完整凸极公式；当前执行链始终使用平均SVPWM，没有接入死区模块。基线设计值已用于第一次产生速度环增益，但修改这些兼容字段不会自动重整定。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $R_s$ | pmsmCfg.Rs / emfCfg.Rs | Ω | 直接使用 |
| $L_d,L_q$ | pmsmCfg.Ld/Lq、emfCfg.Ld/Lq | H | 原表mH乘$10^{-3}$得到工程H |
| $\psi_m$ | pmsmCfg.Flux / emfCfg.Flux | Wb | 直接使用 |
| $P$ | pmsmCfg.PolePairs | 计数 | 数值不换算；原表单位空白，不重写原表 |
| $J$ | pmsmCfg.J | kg·m² | 直接使用 |
| $\theta_r,\hat\theta_r$ | Plant.theta_e / Observer.theta_hat | 电角rad | 直接使用；Position0为机械位置，乘P |
| $\omega_r,\hat\omega_r$ | P×物理机械速度 / Observer.omega_hat | 电角rad/s | 机械速度乘P；估计机械速度除P |
| $\omega_m$ | focCfg.SpeedReference / Plant.speed_mechanical | 机械rad/s | 直接使用；rpm=$60\omega_m/(2\pi)$ |
| $i_d,i_q$ | 真实或参考dq电流（明确true/reference后缀） | A | 直接使用，相峰值约定 |
| $V_{dc}$ | fwCfg.BusValues / bus_voltage | V | 直接使用；瞬时输入优先于名义inverterCfg.Vdc |
| $T_{m\_BLAC},T_L$ | Plant.torque / load_torque | N·m | 直接使用，负母线功率表示回馈 |

符号表以[用户维护版本](../../../../../docs/userdocs/符号定义表.md)为准。原表$\theta_m$表示交叉饱和角，不拿它表示轴位置。原表$B$为N·s/m，与此模型旋转黏性阻尼单位不同；本模块另定义$b_{rot}$（N·m·s/rad）映射pmsmCfg.B，没有几何关系时不直接换算。$\Delta_L=L_d-L_q$、$I_{max}$、$U_a$、互锁许可/计数是本模块局部量。

### pmsmCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `pmsmCfg.Rs` | 0.5 | Ω | 定子相电阻 |
| `pmsmCfg.Ld` | 0.001 | H | d轴电感 |
| `pmsmCfg.Lq` | 0.0012 | H | q轴电感 |
| `pmsmCfg.Flux` | 0.035 | Wb | 永磁体磁链 |
| `pmsmCfg.PolePairs` | 4 | 计数 | 极对数 |
| `pmsmCfg.J` | 0.0005 | kg·m² | 转动惯量 |
| `pmsmCfg.B` | 0.0001 | N·m·s/rad | 本模型局部旋转黏性阻尼，见符号映射 |
| `pmsmCfg.Id0` | 0 | A | 初始真实d电流 |
| `pmsmCfg.Iq0` | 0 | A | 初始真实q电流 |
| `pmsmCfg.Speed0` | 0 | 机械rad/s | 物理机械初速 |
| `pmsmCfg.Position0` | 0.1 | 机械rad | 物理机械初始位置，电角为P倍 |

### currentCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `currentCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `currentCfg.BandwidthHz` | 500 | Hz | 名义带宽 |
| `currentCfg.Kpd` | 3.141592653589793 | V/A | d轴比例增益 |
| `currentCfg.Kpq` | 3.7699111843077513 | V/A | q轴比例增益 |
| `currentCfg.Kid` | 1570.7963267948965 | V/(A·s) | d轴积分增益 |
| `currentCfg.Kiq` | 1570.7963267948965 | V/(A·s) | q轴积分增益 |
| `currentCfg.Kaw` | 20000 | 1/s | 抗饱和回算增益 |

### inverterCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `inverterCfg.Vdc` | 48 | V | 名义母线；实际母线由输入覆盖 |
| `inverterCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `inverterCfg.PwmTs` | 5e-05 | s | PWM名义周期 |
| `inverterCfg.LinearLimit` | 26.604300404257955 | V | 派生电压圆半径 |

### timingCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `timingCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `timingCfg.FeedbackTicks` | 0 | 拍 | 测量延迟拍数 |
| `timingCfg.ActuationTicks` | 1 | 拍 | 占空比执行延迟拍数 |

### motionCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `motionCfg.Ts` | 0.001 | s | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.NaturalFrequency` | 20 | Hz | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.Damping` | 0.9 | 1 | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.Kt` | 0.21000000000000002 | N·m/A | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.Kp` | 0.08523809523809524 | A/(rad/s) | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.Ki` | 0.9523809523809523 | A/rad | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.Kaw` | 20 | 1/s | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.PositionKp` | 8 | 1/s | 共用基线兼容字段；本App不读取此字段调节运行 |
| `motionCfg.SpeedLimit` | 260 | 机械rad/s | 斜坡速度限值 |
| `motionCfg.AccelerationLimit` | 200 | 机械rad/s² | 斜坡加速度限值 |
| `motionCfg.CurrentLimit` | 8 | A | 共用基线兼容字段；本App不读取此字段调节运行 |

### deadtimeCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `deadtimeCfg.DeadTime` | 2e-06 | s | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.DeviceDrop` | 0 | V | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.CurrentBlend` | 0.1 | A | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.ModelEnable` | 0 | 标志 | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.CompensationEnable` | 0 | 标志 | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.CompensationScale` | 1 | 1 | 共用基线兼容字段；本App不读取此字段调节运行 |
| `deadtimeCfg.SwitchingStep` | 1e-07 | s | 共用基线兼容字段；本App不读取此字段调节运行 |

### experimentCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `experimentCfg.UseInverter` | 1 | 标志 | 共用基线兼容字段；本App不读取此字段调节运行 |
| `experimentCfg.UseTiming` | 1 | 标志 | 选择有执行延迟的占空比 |
| `experimentCfg.Step` | 5e-06 | s | 物理对象及固定求解步长 |
| `experimentCfg.LogTs` | 5e-05 | s | 共用基线兼容字段；本App不读取此字段调节运行 |
| `experimentCfg.Duration` | 2.2 | s | 停止时间 |

### focCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `focCfg.Direction` | 1 | ±1 | 给定旋转方向及观测EMF符号 |
| `focCfg.SpeedReference` | 210 | 机械rad/s | 默认最终机械速度给定 |
| `focCfg.SpeedInitial` | 0 | 机械rad/s | 给定斜坡初值，不是物理初速 |
| `focCfg.CommandTime` | 0.05 | s | 速度命令阶跃时刻 |
| `focCfg.LoadTorque` | 0.1 | N·m | 阶跃后外负载 |
| `focCfg.LoadTime` | 0.9 | s | 负载阶跃时刻 |
| `focCfg.Enable` | 1 | 标志 | 默认总请求使能 |
| `focCfg.Reset` | 0 | 标志 | 默认复位输入 |
| `focCfg.ObserverEnable` | 1 | 标志 | 默认观测器使能 |
| `focCfg.CurrentMax` | 8 | A | 共用基线兼容字段；本App不读取此字段调节运行 |
| `focCfg.Kt` | 0.21000000000000002 | N·m/A | 共用基线兼容字段；本App不读取此字段调节运行 |
| `focCfg.VoltageAlignmentEnable` | 1 | 标志 | 启动对齐电压支路使能 |
| `focCfg.AlignmentVoltageGain` | 0.5 | V/A | 对齐电流转换到电压的增益 |
| `focCfg.FrameCorrectionTolerance` | 1e-10 | 电角rad | 额外坐标角修正阈值 |

### refCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `refCfg.MtpaEnable` | 1 | 标志 | 使能MTPA查表 |
| `refCfg.FwEnable` | 1 | 标志 | 使能弱磁状态 |
| `refCfg.CurrentMax` | 8 | A | 参考电流矢量半径 |
| `refCfg.IdMin` | -7 | A | 参考d电流下界 |
| `refCfg.VoltageReserve` | 0.95 | 1 | 分配器电压预留比例 |
| `refCfg.FwVoltageMargin` | 0.2 | V | 弱磁目标额外电压余量 |
| `refCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `refCfg.FwTs` | 0.001 | s | 弱磁滤波/积分周期 |
| `refCfg.FilterTau` | 0.003 | s | 弱磁需求低通时间常数 |
| `refCfg.FwKi` | 50 | A/(V·s) | 电压误差到d电流的积分增益 |
| `refCfg.IdSlew` | 200 | A/s | 弱磁d电流每秒最大变化 |
| `refCfg.TablePoints` | 257 | 点 | MTPA生成表点数 |
| `refCfg.SpeedTs` | 0.001 | s | 转矩速度PI周期 |
| `refCfg.SpeedKp` | 0.017900000000000003 | N·m/(rad/s) | 转矩速度PI比例增益 |
| `refCfg.SpeedKi` | 0.2 | N·m/rad | 转矩速度PI积分增益 |
| `refCfg.SpeedKaw` | 1000 | 1/s | 分配转矩回算增益 |
| `refCfg.IdTable` | 257项，由refresh生成 | A | 由电机和电流圆生成的MTPA负d表 |
| `refCfg.TorqueGrid` | 257项，由refresh生成 | N·m | 与IdTable一一对应的转矩网格 |
| `refCfg.MaxTorque` | 1.681750870527378 | N·m | MTPA表最大转矩 |
| `refCfg.Kt` | 0.21000000000000002 | N·m/A | 零d电流名义转矩常数 |
| `refCfg.VoltageFactor` | 0.5265434455009387 | 1 | 电压预留/最小占空比派生比例 |
| `refCfg.FilterAlpha` | 0.75 | 1 | 由FilterTau和FwTs派生低通系数 |

### startupCfg

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

### handoverCfg

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

### pllCfg

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

### emfCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `emfCfg.Ts` | 5e-05 | s | 本结构所用离散周期 |
| `emfCfg.Rs` | 0.5 | Ω | 定子相电阻 |
| `emfCfg.Ld` | 0.001 | H | d轴电感 |
| `emfCfg.Lq` | 0.0012 | H | q轴电感 |
| `emfCfg.Flux` | 0.035 | Wb | 永磁体磁链 |
| `emfCfg.PolePairs` | 4 | 计数 | 极对数 |
| `emfCfg.BandwidthHz` | 300 | Hz | 名义带宽 |
| `emfCfg.MinEmf` | 1 | V | 观测器最小EMF幅值 |
| `emfCfg.MinOmega` | 30 | 电角rad/s | 最小资格电角速度 |
| `emfCfg.MaxResidual` | 1.5 | A | 观测电流残差资格上限 |

### fwCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `fwCfg.BusTimes` | 0 | s | 实际母线分段保持事件时刻，首项0 |
| `fwCfg.BusValues` | 48 | V | 对应实际母线，每项必须正有限 |

### startGuardCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `startGuardCfg.Enable` | 1 | 标志 | 默认1；0绕过互锁，仅用于已归档反例/等价检查 |
| `startGuardCfg.ObserveTime` | 0.05 | s | 允许启动前连续观察时间 |
| `startGuardCfg.MaxStartEmf` | 0.25 | V | 允许静止对齐的估算EMF幅值上限 |
| `startGuardCfg.ObserveTicks` | 1000 | 拍 | ceil(ObserveTime/currentCfg.Ts) |

### bridgeCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `bridgeCfg.Rs` | 0.5 | Ω | 定子相电阻；由pmsmCfg同步覆盖 |
| `bridgeCfg.Ld` | 0.001 | H | d轴电感；由pmsmCfg同步覆盖 |
| `bridgeCfg.Lq` | 0.0012 | H | q轴电感；由pmsmCfg同步覆盖 |
| `bridgeCfg.Flux` | 0.035 | Wb | 永磁体磁链；由pmsmCfg同步覆盖 |
| `bridgeCfg.PolePairs` | 4 | 计数 | 极对数；由pmsmCfg同步覆盖 |
| `bridgeCfg.J` | 0.0005 | kg·m² | 转动惯量；由pmsmCfg同步覆盖 |
| `bridgeCfg.B` | 0.0001 | N·m·s/rad | 本模型局部旋转黏性阻尼，见符号映射；由pmsmCfg同步覆盖 |
| `bridgeCfg.Id0` | 0 | A | 初始真实d电流；由pmsmCfg同步覆盖 |
| `bridgeCfg.Iq0` | 0 | A | 初始真实q电流；由pmsmCfg同步覆盖 |
| `bridgeCfg.Speed0` | 0 | 机械rad/s | 物理机械初速；由pmsmCfg同步覆盖 |
| `bridgeCfg.Position0` | 0.1 | 机械rad | 物理机械初始位置，电角为P倍；由pmsmCfg同步覆盖 |
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
| `bridgeCfg.Vector` | 17项，由refresh生成 | 逐项SI/标志 | 打包后的库配置向量，按refresh生成 |

### normalizedInverterCfg

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| `normalizedInverterCfg.Vdc` | 1 | 归一化基准 | 名义母线；实际母线由输入覆盖 |
| `normalizedInverterCfg.MinDuty` | 0.02 | 1 | 每相最小占空比 |
| `normalizedInverterCfg.PwmTs` | 5e-05 | s | PWM名义周期 |
| `normalizedInverterCfg.LinearLimit` | 0.5542562584220407 | 归一化电压 | 派生电压圆半径 |


## 输入信号

| 名称/列 | 单位 | 类型或初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|---|
| speed_reference / 1 | 机械rad/s | double，初始0、0.05s给210 | testStim → inputs.y1 | 速度斜坡与转矩PI |
| load_torque / 2 | N·m | double，0.9s由0到0.1 | testStim → Plant | 物理负载；方程中从电磁转矩减去 |
| enable / 3 | 0/1 | double，默认1 | testStim → StartInterlock | 请求启动，不直接等同门极许可 |
| reset / 4 | 0/1 | double，默认0 | testStim → 观察器/互锁/控制 | 清控制状态；物理Plant不清零 |
| direction / 5 | ±1 | double，默认+1 | testStim → 观察器/互锁/启动 | 方向变化撤销许可并重新观察 |
| observer_enable / 6 | 0/1 | double，默认1 | testStim → Observer | 禁用时不能获得初次启动许可 |
| bus_voltage / 7 | V | 正有限double，默认48 | testStim → Plant、Allocator、VoltageStage | 三处使用同一拍真实母线 |

输入由[sensorless_fw_stimulus.m](../build_process/sensorless_fw_stimulus.m)生成。事件必须落在控制采样网格；默认模型ZOH保持50μs，物理桥以5μs积分。

## 过程变量

| 名称 | 单位 | 类型或状态初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|---|
| bridge物理状态 | 电流A、机械rad/s、机械rad | 4项，来自pmsmCfg的初值 | Plant/Motor | 关断与reset仍连续推进，不由控制复位清零 |
| EEMF状态 | A、V | 估计电流2项、EEMF2项，复位为0 | Observer/Estimator | 当前状态用于输出，实际电压/电流用于下一状态 |
| PLL状态 | 电角rad、电角rad/s及计数 | pllCfg.Theta0/Omega0及0计数 | EEMF内PLL | 包角相位误差、积分速度及资格 |
| Startup / Handover | 电角rad、电角rad/s、A及计数 | 各参数State0 | Controller | 对齐/I-f与持续资格、混合、失锁 |
| 电流PI积分 | V | 初值0 | Controller/CurrentPI | 坐标旋转跟踪、对齐跟踪及可实现电压回算 |
| 速度PI积分 | N·m | 初值0 | Controller/SpeedPI | 估计机械速度误差积分，按分配转矩回算 |
| id_fw / filtered_voltage | A / V | 0 / 0 | CurrentAllocator内部 | 每1ms读当前状态、计算下一状态；复位/禁能清控制状态 |
| voltage_demand_prev | V | 0 | VoltageDemandPrevious | 上一完整电流拍的PI+前馈模长，避免代数环 |
| WarmCount / PermitMemory / LastDirection | 拍 / boolean / ±1 | 0 / false / focCfg.Direction | StartInterlock | 观察计数、锁存许可及方向事件 |
| normalizedInverterCfg | 归一化值 | Vdc=1 | VoltageStage局部mask | 请求先除实际Vdc，恢复电压后计算回算残差 |

## 输出信号

以下日志表按实际Mux顺序给出，`record.<组>.columns.<名称>`可取得同一列号。源名称相对于所在子系统；全局actuation组相对于根图。标志入日志后为double。Source别名与脚本构建时保持一致。

### plant_trace：36列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1–2 | `current_ab` | A | `#Motor.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 3–5 | `phase_current` | A | `#Motor.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 6–8 | `phase_voltage` | V | `#Motor.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 9–10 | `voltage_ab` | V | `#Motor.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 11 | `speed_mechanical` | mechanical rad/s | `#Motor.y5` | 记录该端口当前值；矢量按端口元素顺序 |
| 12 | `theta_e` | electrical rad | `#Motor.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 13 | `torque` | N*m | `#Motor.y7` | 记录该端口当前值；矢量按端口元素顺序 |
| 14 | `dc_current` | A | `#Motor.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 15–17 | `diode_states` | -1/0/+1 | `#Motor.y9` | 记录该端口当前值；矢量按端口元素顺序 |
| 18 | `magnetic_energy` | J | `#Motor.y10` | 记录该端口当前值；矢量按端口元素顺序 |
| 19 | `kinetic_energy` | J | `#Motor.y11` | 记录该端口当前值；矢量按端口元素顺序 |
| 20 | `bridge_loss` | W | `#Motor.y12` | 记录该端口当前值；矢量按端口元素顺序 |
| 21 | `equation_residual` | V | `#Motor.y13` | 记录该端口当前值；矢量按端口元素顺序 |
| 22–24 | `next_phase_current` | A | `#Motor.y14` | 记录该端口当前值；矢量按端口元素顺序 |
| 25 | `neutral_voltage` | V | `#Motor.y15` | 记录该端口当前值；矢量按端口元素顺序 |
| 26–28 | `pole_voltage` | V | `#Motor.y16` | 记录该端口当前值；矢量按端口元素顺序 |
| 29 | `load_torque` | N*m | `#load_torque.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 30 | `bus_voltage` | V | `#bus_voltage.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 31 | `bridge_mode` | 0/1/2 | `#mode.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 32–34 | `duty` | 1 | `#duty.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 35 | `id_true` | A | `#RotorPark.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 36 | `iq_true` | A | `#RotorPark.y2` | 记录该端口当前值；矢量按端口元素顺序 |

### observer_trace：20列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1 | `theta_hat` | electrical rad | `#Estimator.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 2 | `omega_hat` | electrical rad/s | `#Estimator.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 3 | `valid` | 1 | `#Estimator.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 4 | `emf_alpha` | V | `#Estimator.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 5 | `emf_beta` | V | `#Estimator.y5` | 记录该端口当前值；矢量按端口元素顺序 |
| 6 | `i_hat_alpha` | A | `#Estimator.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 7 | `i_hat_beta` | A | `#Estimator.y7` | 记录该端口当前值；矢量按端口元素顺序 |
| 8 | `residual_alpha` | A | `#Estimator.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 9 | `residual_beta` | A | `#Estimator.y9` | 记录该端口当前值；矢量按端口元素顺序 |
| 10 | `phase_measured` | rad | `#Estimator.y10` | 记录该端口当前值；矢量按端口元素顺序 |
| 11 | `emf_magnitude` | V | `#Estimator.y11` | 记录该端口当前值；矢量按端口元素顺序 |
| 12 | `phase_error` | rad | `#Estimator.y12` | 记录该端口当前值；矢量按端口元素顺序 |
| 13–14 | `current_ab` | A | `#current_ab.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 15–16 | `observer_voltage` | V | `#VoltageAge.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 17 | `observer_residual` | A | `#ResidualNorm.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 18 | `enable` | 1 | `#enable.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 19 | `reset` | 1 | `#reset.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 20 | `direction` | 1 | `#direction.y1` | 记录该端口当前值；矢量按端口元素顺序 |

### controller_trace：46列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1–2 | `control_current` | A | `#ControlCurrent.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 3 | `speed_reference` | mechanical rad/s | `#SpeedReferenceSlew.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 4 | `speed_error` | mechanical rad/s | `#SpeedErrorSample.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 5 | `torque_request` | N*m | `#SpeedPI.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 6 | `torque_allocated` | N*m | `#CurrentAllocator.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 7 | `torque_estimated` | N*m | `#EstimatedTorqueSample.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 8 | `integral_torque` | N*m | `#SpeedPI.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 9 | `iq_closed` | A | `#CurrentAllocator.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 10–11 | `reference` | A | `#ReferenceBlend.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 12–13 | `voltage_pi` | V | `#CurrentPI.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 14–15 | `integral_base` | V | `#CurrentPI.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 16–17 | `integral_state` | V | `#CurrentPI.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 18–19 | `voltage_residual` | V | `#voltage_residual.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 20 | `theta_start` | electrical rad | `#Startup.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 21 | `omega_start` | electrical rad/s | `#Startup.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 22 | `id_start` | A | `#Startup.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 23 | `iq_start` | A | `#Startup.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 24 | `ready` | 1 | `#Startup.y5` | 记录该端口当前值；矢量按端口元素顺序 |
| 25 | `startup_mode` | 1 | `#Startup.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 26 | `startup_fault` | 1 | `#Startup.y7` | 记录该端口当前值；矢量按端口元素顺序 |
| 27 | `startup_elapsed` | s | `#Startup.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 28 | `theta_used` | electrical rad | `#Handover.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 29 | `omega_base` | electrical rad/s | `#Handover.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 30 | `omega_frame` | electrical rad/s | `#Handover.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 31 | `beta` | 1 | `#Handover.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 32 | `handover_mode` | 1 | `#Handover.y5` | 记录该端口当前值；矢量按端口元素顺序 |
| 33 | `handover_fault` | 1 | `#Handover.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 34 | `acquired` | 1 | `#Handover.y7` | 记录该端口当前值；矢量按端口元素顺序 |
| 35 | `run` | 1 | `#Handover.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 36 | `qualification_count` | samples | `#Handover.y9` | 记录该端口当前值；矢量按端口元素顺序 |
| 37 | `loss_count` | samples | `#Handover.y10` | 记录该端口当前值；矢量按端口元素顺序 |
| 38 | `phase_offset` | rad | `#Handover.y11` | 记录该端口当前值；矢量按端口元素顺序 |
| 39 | `delta_extra` | rad | `#ExtraAngle.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 40 | `track` | 1 | `#TrackDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 41 | `auto_sampled` | 1 | `#AutoDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 42 | `voltage_alignment` | 1 | `#VoltageAlignDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 43–44 | `voltage_selected` | V | `#VoltageSelected.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 45–46 | `pi_residual` | V | `#PIResidualUsed.y1` | 记录该端口当前值；矢量按端口元素顺序 |

### allocation_trace：25列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1 | `id_reference` | A | `#CurrentAllocator.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 2 | `iq_reference` | A | `#CurrentAllocator.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 3 | `allocated_torque` | N*m | `#CurrentAllocator.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 4 | `id_mtpa` | A | `#CurrentAllocator.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 5 | `iq_mtpa` | A | `#CurrentAllocator.y5` | 记录该端口当前值；矢量按端口元素顺序 |
| 6 | `id_fw` | A | `#CurrentAllocator.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 7 | `filtered_voltage` | V | `#CurrentAllocator.y7` | 记录该端口当前值；矢量按端口元素顺序 |
| 8 | `voltage_available` | V | `#CurrentAllocator.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 9 | `predicted_voltage` | V | `#CurrentAllocator.y9` | 记录该端口当前值；矢量按端口元素顺序 |
| 10 | `current_margin` | A | `#CurrentAllocator.y10` | 记录该端口当前值；矢量按端口元素顺序 |
| 11 | `voltage_margin` | V | `#CurrentAllocator.y11` | 记录该端口当前值；矢量按端口元素顺序 |
| 12 | `torque_residual` | N*m | `#CurrentAllocator.y12` | 记录该端口当前值；矢量按端口元素顺序 |
| 13 | `current_limited` | 1 | `#CurrentLimitFlagDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 14 | `voltage_limited` | 1 | `#VoltageLimitFlagDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 15 | `feasible` | 1 | `#FeasibleFlagDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 16 | `fw_active` | 1 | `#WeakeningFlagDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 17 | `voltage_error` | V | `#CurrentAllocator.y17` | 记录该端口当前值；矢量按端口元素顺序 |
| 18 | `model_voltage_demand` | V | `#CurrentAllocator.y18` | 记录该端口当前值；矢量按端口元素顺序 |
| 19 | `effective_voltage_demand` | V | `#CurrentAllocator.y19` | 记录该端口当前值；矢量按端口元素顺序 |
| 20 | `torque_request` | N*m | `#SpeedPI.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 21 | `omega_e` | electrical rad/s | `#Handover.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 22 | `bus_voltage` | V | `#bus_voltage.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 23 | `voltage_demand_prev` | V | `#VoltageDemandPrevious.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 24 | `drive_enable` | 1 | `#Handover.y8` | 记录该端口当前值；矢量按端口元素顺序 |
| 25 | `reset` | 1 | `#reset.y1` | 记录该端口当前值；矢量按端口元素顺序 |

### actuation_trace：27列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1–7 | `stimulus` | mixed | `#stimulus.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 8–9 | `voltage_request` | V | `#Controller.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 10 | `theta_control` | electrical rad | `#Controller.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 11–13 | `phase_voltage` | V | `#VoltageStage.y6` | 记录该端口当前值；矢量按端口元素顺序 |
| 14–16 | `duty_command` | 1 | `#VoltageStage.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 17–19 | `duty_applied` | 1 | `#VoltageStage.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 20 | `voltage_scale` | 1 | `#VoltageStage.y3` | 记录该端口当前值；矢量按端口元素顺序 |
| 21–22 | `voltage_residual` | V | `#VoltageStage.y4` | 记录该端口当前值；矢量按端口元素顺序 |
| 23–25 | `measured_phase_current` | A | `#Measurement.y2` | 记录该端口当前值；矢量按端口元素顺序 |
| 26–27 | `measured_current_ab` | A | `#Measurement.y1` | 记录该端口当前值；矢量按端口元素顺序 |

### guard_trace：9列

| 列 | 名称 | 单位 | 来源端口 | 用途 |
|---|---|---|---|---|
| 1 | `request_enable` | 1 | `#request_enable.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 2 | `reset` | 1 | `#reset.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 3 | `observer_enable` | 1 | `#observer_enable.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 4 | `emf_magnitude` | V | `#emf_magnitude.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 5 | `direction` | -1/+1 | `#direction.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 6 | `warm_count` | samples | `#WarmCount.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 7 | `permit` | 1 | `#PermitSelected.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 8 | `qualified` | 1 | `#QualifiedDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |
| 9 | `direction_changed` | 1 | `#DirectionChangedDouble.y1` | 记录该端口当前值；矢量按端口元素顺序 |

## Scope 通道

以下29组是原生编译后的Scope清单，通道宽度按实际端口展开。所有Scope一个输入Mux，表内序号为Scope显示通道；不是六组日志的全局列号。来源端口数字从1开始。完整原生记录见[fw_native_inventory.json](../waveform_analysis/fw_native_inventory.json)。

### Controller/AllocationFlagsScope（4通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `current_limited` | `Controller/CurrentLimitFlagDouble.y1` | 1，double | current_limited随工况的实际值；矢量按abc或dq顺序 |
| 2 | `voltage_limited` | `Controller/VoltageLimitFlagDouble.y1` | 1，double | voltage_limited随工况的实际值；矢量按abc或dq顺序 |
| 3 | `feasible` | `Controller/FeasibleFlagDouble.y1` | 1，double | feasible随工况的实际值；矢量按abc或dq顺序 |
| 4 | `fw_active` | `Controller/WeakeningFlagDouble.y1` | 1，double | fw_active随工况的实际值；矢量按abc或dq顺序 |

### Controller/AllocationVoltageScope（6通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `filtered_voltage` | `Controller/CurrentAllocator.y7` | V，double | filtered_voltage随工况的实际值；矢量按abc或dq顺序 |
| 2 | `voltage_available` | `Controller/CurrentAllocator.y8` | V，double | voltage_available随工况的实际值；矢量按abc或dq顺序 |
| 3 | `predicted_voltage` | `Controller/CurrentAllocator.y9` | V，double | predicted_voltage随工况的实际值；矢量按abc或dq顺序 |
| 4 | `voltage_margin` | `Controller/CurrentAllocator.y11` | V，double | voltage_margin随工况的实际值；矢量按abc或dq顺序 |
| 5 | `model_voltage_demand` | `Controller/CurrentAllocator.y18` | V，double | model_voltage_demand随工况的实际值；矢量按abc或dq顺序 |
| 6 | `effective_voltage_demand` | `Controller/CurrentAllocator.y19` | V，double | effective_voltage_demand随工况的实际值；矢量按abc或dq顺序 |

### Controller/AngleScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_start` | `Controller/Startup.y1` | electrical rad，double | theta_start随工况的实际值；矢量按abc或dq顺序 |
| 2 | `theta_hat` | `Controller/theta_hat.y1` | 电角rad，double | theta_hat随工况的实际值；矢量按abc或dq顺序 |
| 3 | `theta_used` | `Controller/Handover.y1` | electrical rad，double | theta_used随工况的实际值；矢量按abc或dq顺序 |

### Controller/CurrentAllocationScope（5通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `id_mtpa` | `Controller/CurrentAllocator.y4` | A，double | id_mtpa随工况的实际值；矢量按abc或dq顺序 |
| 2 | `iq_mtpa` | `Controller/CurrentAllocator.y5` | A，double | iq_mtpa随工况的实际值；矢量按abc或dq顺序 |
| 3 | `id_reference` | `Controller/CurrentAllocator.y1` | A，double | id_reference随工况的实际值；矢量按abc或dq顺序 |
| 4 | `iq_reference` | `Controller/CurrentAllocator.y2` | A，double | iq_reference随工况的实际值；矢量按abc或dq顺序 |
| 5 | `id_fw` | `Controller/CurrentAllocator.y6` | A，double | id_fw随工况的实际值；矢量按abc或dq顺序 |

### Controller/CurrentScope（4通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `reference` | `Controller/ReferenceBlend.y1` | A，double | reference随工况的实际值；矢量按abc或dq顺序 |
| 3 | `measured_id` | `Controller/ControlPark.y1` | A，double | measured_id随工况的实际值；矢量按abc或dq顺序 |
| 4 | `measured_iq` | `Controller/ControlPark.y2` | A，double | measured_iq随工况的实际值；矢量按abc或dq顺序 |

### Controller/ExtraAngleScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `delta_extra` | `Controller/ExtraAngle.y1` | rad，double | delta_extra随工况的实际值；矢量按abc或dq顺序 |

### Controller/FrameSpeedScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_start` | `Controller/Startup.y2` | electrical rad/s，double | omega_start随工况的实际值；矢量按abc或dq顺序 |
| 2 | `omega_e` | `Controller/Handover.y2` | electrical rad/s，double | omega_e随工况的实际值；矢量按abc或dq顺序 |
| 3 | `omega_frame` | `Controller/Handover.y3` | electrical rad/s，double | omega_frame随工况的实际值；矢量按abc或dq顺序 |

### Controller/SpeedLoopScope（2通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `speed_reference` | `Controller/SpeedReferenceSlew.y1` | mechanical rad/s，double | speed_reference随工况的实际值；矢量按abc或dq顺序 |
| 2 | `omega_hat/P` | `Controller/MechanicalEstimate.y1` | 机械rad/s，double | omega_hat/P随工况的实际值；矢量按abc或dq顺序 |

### Controller/StateScope（5通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `startup_mode` | `Controller/Startup.y6` | 1，double | startup_mode随工况的实际值；矢量按abc或dq顺序 |
| 2 | `startup_fault` | `Controller/Startup.y7` | 1，double | startup_fault随工况的实际值；矢量按abc或dq顺序 |
| 3 | `handover_mode` | `Controller/Handover.y5` | 1，double | handover_mode随工况的实际值；矢量按abc或dq顺序 |
| 4 | `handover_fault` | `Controller/Handover.y6` | 1，double | handover_fault随工况的实际值；矢量按abc或dq顺序 |
| 5 | `drive_enable` | `Controller/Handover.y8` | 1，double | drive_enable随工况的实际值；矢量按abc或dq顺序 |

### Controller/TorqueLoopScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `torque_request` | `Controller/SpeedPI.y1` | N*m，double | torque_request随工况的实际值；矢量按abc或dq顺序 |
| 2 | `allocated_torque` | `Controller/CurrentAllocator.y3` | N*m，double | allocated_torque随工况的实际值；矢量按abc或dq顺序 |
| 3 | `torque_estimated` | `Controller/EstimatedTorqueSample.y1` | N*m，double | torque_estimated随工况的实际值；矢量按abc或dq顺序 |

### Controller/TransitionScope（2通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `beta` | `Controller/Handover.y4` | 1，double | beta随工况的实际值；矢量按abc或dq顺序 |
| 2 | `track` | `Controller/TrackDouble.y1` | 1，double | track随工况的实际值；矢量按abc或dq顺序 |

### Controller/VoltageScope（4通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `voltage_pi` | `Controller/CurrentPI.y1` | V，double | voltage_pi随工况的实际值；矢量按abc或dq顺序 |
| 3–4 | `voltage_residual` | `Controller/voltage_residual.y1` | V，double | voltage_residual随工况的实际值；矢量按abc或dq顺序 |

### Observer/EmfScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `emf_alpha` | `Observer/Estimator.y4` | V，double | emf_alpha随工况的实际值；矢量按abc或dq顺序 |
| 2 | `emf_beta` | `Observer/Estimator.y5` | V，double | emf_beta随工况的实际值；矢量按abc或dq顺序 |
| 3 | `emf_magnitude` | `Observer/Estimator.y11` | V，double | emf_magnitude随工况的实际值；矢量按abc或dq顺序 |

### Observer/EstimateAngleScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `theta_hat` | `Observer/Estimator.y1` | electrical rad，double | theta_hat随工况的实际值；矢量按abc或dq顺序 |

### Observer/EstimateSpeedScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `omega_hat` | `Observer/Estimator.y2` | electrical rad/s，double | omega_hat随工况的实际值；矢量按abc或dq顺序 |

### Observer/ResidualScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `residual_alpha` | `Observer/Estimator.y8` | A，double | residual_alpha随工况的实际值；矢量按abc或dq顺序 |
| 2 | `residual_beta` | `Observer/Estimator.y9` | A，double | residual_beta随工况的实际值；矢量按abc或dq顺序 |
| 3 | `observer_residual` | `Observer/ResidualNorm.y1` | A，double | observer_residual随工况的实际值；矢量按abc或dq顺序 |

### Observer/ValidityScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `valid` | `Observer/Estimator.y3` | 1，double | valid随工况的实际值；矢量按abc或dq顺序 |
| 2 | `observer_enable` | `Observer/enable.y1` | 0/1，double | observer_enable随工况的实际值；矢量按abc或dq顺序 |
| 3 | `reset` | `Observer/reset.y1` | 1，double | reset随工况的实际值；矢量按abc或dq顺序 |

### Plant/BridgeModeScope（4通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `requested_bridge_mode` | `Plant/mode.y1` | 0/1/2，double | requested_bridge_mode随工况的实际值；矢量按abc或dq顺序 |
| 2–4 | `phase_branch_modes_abc` | `Plant/Motor.y9` | 状态码，double | phase_branch_modes_abc随工况的实际值；矢量按abc或dq顺序 |

### Plant/BusCurrentScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `dc_current` | `Plant/Motor.y8` | A，double | dc_current随工况的实际值；矢量按abc或dq顺序 |

### Plant/BusVoltageScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `bus_voltage` | `Plant/bus_voltage.y1` | V，double | bus_voltage随工况的实际值；矢量按abc或dq顺序 |

### Plant/MechanicalSpeedScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `speed_mechanical` | `Plant/Motor.y5` | 机械rad/s，double | speed_mechanical随工况的实际值；矢量按abc或dq顺序 |

### Plant/TorqueScope（2通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `torque` | `Plant/Motor.y7` | N·m，double | torque随工况的实际值；矢量按abc或dq顺序 |
| 2 | `load_torque` | `Plant/load_torque.y1` | N*m，double | load_torque随工况的实际值；矢量按abc或dq顺序 |

### Plant/TrueCurrentScope（2通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `id_true` | `Plant/RotorPark.y1` | A，double | id_true随工况的实际值；矢量按abc或dq顺序 |
| 2 | `iq_true` | `Plant/RotorPark.y2` | A，double | iq_true随工况的实际值；矢量按abc或dq顺序 |

### StartInterlock/ObservationCountScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `warm_count` | `StartInterlock/WarmCount.y1` | samples，double | warm_count随工况的实际值；矢量按abc或dq顺序 |

### StartInterlock/ObservedEmfScope（1通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `emf_magnitude` | `StartInterlock/emf_magnitude.y1` | V，double | emf_magnitude随工况的实际值；矢量按abc或dq顺序 |

### StartInterlock/PermitScope（4通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1 | `request_enable` | `StartInterlock/request_enable.y1` | 1，double | request_enable随工况的实际值；矢量按abc或dq顺序 |
| 2 | `permit` | `StartInterlock/PermitSelected.y1` | 1，double | permit随工况的实际值；矢量按abc或dq顺序 |
| 3 | `qualified` | `StartInterlock/QualifiedDouble.y1` | 1，double | qualified随工况的实际值；矢量按abc或dq顺序 |
| 4 | `direction_changed` | `StartInterlock/DirectionChangedDouble.y1` | 1，double | direction_changed随工况的实际值；矢量按abc或dq顺序 |

### VoltageStage/ActualPhaseVoltageScope（3通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–3 | `phase_voltage_abc` | `VoltageStage/actual_phase_voltage.y1` | V，double | phase_voltage_abc随工况的实际值；矢量按abc或dq顺序 |

### VoltageStage/DutyScope（6通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–3 | `duty_command_abc` | `VoltageStage/EnabledDuty.y1` | 1，double | duty_command_abc随工况的实际值；矢量按abc或dq顺序 |
| 4–6 | `duty_applied_abc` | `VoltageStage/TimingSelect.y1` | 1，double | duty_applied_abc随工况的实际值；矢量按abc或dq顺序 |

### VoltageStage/VoltageResidualScope（2通道）

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| 1–2 | `voltage_residual_dq` | `VoltageStage/ConsistentResidual.y1` | V，double | voltage_residual_dq随工况的实际值；矢量按abc或dq顺序 |

Handover模式4表示闭环AUTO；Startup/Handover其他状态码见对应[启动库参数](../../../../lib/无感启动/parameter/README.md)和[切换库参数](../../../../lib/无感切换/parameter/README.md)。Plant桥请求0/1/2分别为关断/PWM/主动短路；三相支路状态码含二极管活动集，含义见[物理桥参数](../../../../lib/永磁同步电机/parameter/BRIDGE_PARAMETERS.md)。不要把当前App只使用0/1误写成已验证主动短路控制策略。

[模块](../README.md) · [运行](../build_process/USAGE.md) · [公式](../docs/公式推导.md)
