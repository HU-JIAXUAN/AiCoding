# V/f 参数与信号

## 配置参数

默认值来自 [vf_app_parameters.m](vf_app_parameters.m)，工况参数来自 [vf_app_validation_parameters.m](vf_app_validation_parameters.m)。载入时把结构体和刺激量写入 Model Workspace；测试覆盖通过 SimulationInput 注入。

| M 字段 | 默认值与单位 | 用途 |
| --- | --- | --- |
| motorCfg.Rs / Ld / Lq | 0.5 Ω / 0.001 H / 0.001 H | SPMSM 定子相电阻与两轴电感 |
| motorCfg.Flux / PolePairs | 0.035 Wb / 4 | 永磁磁链 ψm / 极对数 P |
| motorCfg.J / B | 0.0005 kg·m² / 0.001 N·m·s/rad | 惯量 / 旋转黏性阻尼；B 是代码字段，公式用局部符号 b_rot |
| motorCfg.Id0 / Iq0 / Speed0 / Position0 | 0 A / 0 A / 0 rad/s / 0 rad | 初始电流、机械速度和电角度 |
| openLoopCfg.Ts / Kind / Theta0 | 62.5 μs / 2 / −π/2 rad | 控制采样时间、命令类型、软件初相 |
| openLoopCfg.MaximumFrequency / FrequencySlew | 80 Hz / 40 Hz/s | 双向频率限幅和斜率 |
| openLoopCfg.ObserveTime / ObserveTimeout | 0.05 / 0.5 s | 低电压、低电流持续确认和最长观察时间 |
| openLoopCfg.StartVoltageMaximum / StartCurrentMaximum | 0.25 V / 0.2 A | 启动观察门限 |
| openLoopCfg.AlignTime / AlignRampTime | 0.25 / 0.1 s | 零频率对齐及幅值爬坡 |
| openLoopCfg.AlignAmplitude / AmplitudeSlew | 0.5 V / 50 V/s | 对齐幅值及运行幅值斜率 |
| openLoopCfg.VfSlope / VfBoost | 0.219911 V/Hz / 0.5 V | 运行 V/f 斜率及低频电压补偿 |
| openLoopCfg.CurrentTrip | 12 A | 采样电流幅值过限闭锁 |
| powerCfg.Vdc / MinDuty | 48 V / 0.02 | 实际默认母线及对称占空比留量 |
| experimentCfg.Duration / Step | 2 s / 12.5 μs | 仿真时长、固定离散步长 |
| experimentCfg.Frequency / LoadTorque / LoadTime / LogPeriod | 40 Hz / 0.05 N·m / 1.5 s / 1 ms | 默认频率、阶跃负载、阶跃时刻、导出最小间隔 |

currentCfg 仅保存 Ts 供共用初始化使用；该 App 没有 PI 参数。V/f 斜率默认由 2πψm 得到；修改磁链后同步更新该字段。

`powerCfg.Vdc` 是输入工况默认实际母线。`inverterCfg.Vdc=1` 是归一化调制底数；实际母线从第 5 列进入调制分母与桥对象，电压限幅使用同一个实际值。

## 输入信号

| 工况列 | 信号 | 单位与语义 |
| --- | --- | --- |
| 1 | frequency_ref | Hz，带符号电频率 |
| 2 | enable | 逻辑，0 禁能 |
| 3 | reset | 逻辑，复位并关断门极 |
| 4 | load_torque | N·m，正转阻力为正，反转阻力为负 |
| 5 | bus_voltage | V，实际母线 |

## 过程变量

软件电角度 θc 和软件电频率 fc 生成虚拟坐标系；对象真实转子电角度 θr 与机械角速度 ωr 只用作对照。按频率给出电压幅值和相位，电流由电机、母线和负载决定。桥输出的电流与端电压幅值采样后进入观察/保护。阶段 0 待机、1 观察、2 对齐、3 运行、7 故障。故障 0 无、1 过流、2 输入非法、3 观察超时、4 内部阶段非法。禁能/复位立即关断门极，不把对象转速清零。

## 输出信号

| app_trace 列 | 字段顺序 | 单位 |
| --- | --- | --- |
| 1–5 | frequency_ref, enable, reset, load_torque, bus_voltage | Hz / 逻辑 / 逻辑 / N·m / V |
| 6–13 | theta_control, frequency_control, amplitude, pwm_enable, stage, fault, elapsed, amplitude_limited | rad / Hz / V / 逻辑 / 枚举 / 枚举 / s / 逻辑 |
| 14–15 | current_ab（采样后的 iα、iβ） | A |
| 16–18 | speed_mechanical, theta_true, torque | rad/s / rad / N·m |
| 19–21 | phase_current（a/b/c） | A |
| 22–24 | voltage_ab（α/β）, dc_current | V / V / A |
| 25–28 | magnetic_energy, kinetic_energy, bridge_loss, equation_residual | J / J / W / W |
| 29–30 | current_virtual_dq | A |
| 31–36 | voltage_request, voltage_limited, voltage_residual（各 d/q 两列） | V |
| 37–39 | duty（a/b/c） | 无量纲 |
| 40–43 | voltage_scale, bridge_mode, current_norm, terminal_voltage_norm | 无量纲 / 枚举 / A / V |

`physical_trace` 是对象快采样，列 1–4 分别为电流矢量幅值 A、机械速度 rad/s、电磁转矩 N·m、方程功率残差 W。仿真工况检查用原始序列；波形 CSV 仅用于浏览，首列是时间 s。

## Scope 通道

每组 Scope 是一个 Mux 向量端口。下表按向量元素编号，时间轴为 s。观察组显示对象原始幅值；启动逻辑读取 62.5 μs 保持值。CSV 及 `app_trace` 与 Scope 顺序不同。

| Scope 块 | 通道顺序与单位 |
| --- | --- |
| `SpeedScope` | 1: 软件电频率 Hz；2: 同步机械参考 rad/s；3: 对象实际机械速度 rad/s |
| `AngleScope` | 1: 软件电角度 rad；2: 对象实际转子电角度 rad；3: 两者环绕相位差 rad |
| `CurrentScope` | 1–2: 对象实际 iα、iβ A（快步长）；3–4: 虚拟 d/q 电流 A；5: 对象电流矢量幅值 A（快步长） |
| `VoltageScope` | 1–2: 虚拟 dq 请求 V；3–4: 虚拟 dq 限幅后 V；5–6: 对象端实际 αβ 电压 V；7: 限幅比例 |
| `DutyScope` | 1–3: a/b/c 占空比；4: 桥模式（0关断/续流，1平均PWM） |
| `StatusScope` | 1: 使能；2: 复位；3: PWM允许；4: 阶段；5: 故障码；6: 公用模块电压幅值限幅标志 |
| `ObservationScope` | 1: 实际电流幅值 A；2: 实际端电压幅值 V；3: 当前阶段计时 s |
| `AmplitudeScope` | 1: 软件给定幅值 V；2: 软件电频率 Hz |

符号、含义和单位按[工程符号表](../../../../../docs/userdocs/符号定义表.md)；Hz、软件坐标和 b_rot 为本 App 局部量。
