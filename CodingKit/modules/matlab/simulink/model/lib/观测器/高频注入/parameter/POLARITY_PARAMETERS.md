# PolarityPulse 参数、状态与接口

## 配置参数

入口为 [hfi_polarity_parameters.m](hfi_polarity_parameters.m)，修改后调用 [refresh_hfi_polarity_parameters.m](refresh_hfi_polarity_parameters.m)。Mask引用本模块或App工作区中的`polarityCfg`，不在SLX中维护第二份默认值。此方法以正d电流使增量Ld下降为极性约定；反向饱和特性的电机需要先确认符号。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e−6 | s | 离散更新周期 |
| PulseVoltage / PulseTime | 4 / .001 | V / s | 正、负轴向脉冲幅值与时长，各20拍 |
| AxisStableTime | .005 | s | 轴线有效且低速连续成立100拍后冻结脉冲方向 |
| SettleTime / DecayStableTime | .005 / .0005 | s | 停止HFI后及每次脉冲后的最短等待、低电流持续时间 |
| AxisTimeout / StageTimeout / TotalTimeout | .2 / .05 / .35 | s | 等待轴线、单段电流衰减、整个启动的超时 |
| CurrentDecay / MaxCurrent | .03 / 6 | A | 进入下一脉冲的电流模门限、启动阶段过流门限 |
| MaxAxisSpeed | 2 | 电角rad/s | 脉冲开始前的滤波速度模上限 |
| MinPeakDifference / MinRelativeDifference | .1 / .03 | A / 1 | 两侧峰值差绝对值、相对平均峰值的下限，均需满足 |
| MinPulseDose | .001 | V·s | 每侧实际轴向电压积分下限 |
| MaxDoseMismatch | .05 | 1 | 两侧伏秒差/两侧平均伏秒的上限 |
| MaxCrossDoseFraction | .1 | 1 | 横向绝对伏秒/两侧轴向伏秒之和的上限 |
| MinPulseVoltage | .5 | V | 计入脉冲伏秒的实际轴向电压模下限 |
| SpeedFilterTime | .005 | s | 脉冲准入速度低通时间常数，SpeedA=exp(−Ts/τ) |
| InitialState | zeros(19,1) | 混合 | 全部状态初始清零 |
| Settings | 19元素 | 混合 | refresh生成，顺序见下文，不直接编辑 |

`Settings=[Ts,Vpulse,PulseSamples,AxisStableSamples,SettleSamples,DecayStableSamples,AxisTimeoutSamples,StageTimeoutSamples,TotalTimeoutSamples,CurrentDecay,MaxCurrent,MaxAxisSpeed,MinPeakDifference,MinRelativeDifference,MinPulseDose,MaxDoseMismatch,MaxCrossDoseFraction,MinPulseVoltage,SpeedA]`。所有时间必须落在Ts网格上。

## 输入信号

| 端口 | 名称 | 单位/类型 | 来源及作用 |
|---|---|---|---|
| u1–u2 | u_alpha / u_beta | V，double | 实际执行或重建电压；u[k]保存供下一拍使用 |
| u3–u4 | i_alpha / i_beta | A，double | 与实际电压区间对齐的采样电流，i[k]结束u[k−1]区间 |
| u5 | theta_axis | 电角rad，double | HFI连续轴线分支，尚有π歧义 |
| u6 | omega_axis | 电角rad/s，double | HFI估计速度，内部低通后检查脉冲准入 |
| u7 | axis_valid | 0/1 | 轴线锁定资格；脉冲期间允许暂时失锁，恢复后再次等待锁定 |
| u8 | saliency_qualified | 0/1 | 独立凸极资格；开始脉冲后丢失则锁存故障 |
| u9–u10 | enable / reset | 逻辑兼容 | reset优先，禁能或复位清除状态和极性结论 |

没有真实角度、Ld/Lq或真实磁极输入。凸极资格由App决定；探针快照的资格不等于持续物理健康监测。

## 过程变量

`PolarityStates`为19元素UnitDelay，`PolarityUpdate`计算下一拍状态，`PolarityOutput`只根据当前保持状态及资格产生请求，避免实际电压到电压请求的代数环。

| 状态索引 | 名称 | 初值/单位 | 用途 |
|---|---|---|---|
| 1 | stage | 0，枚举 | 0初始化；1等轴线；2停HFI/等待衰减；3正脉冲；4正侧衰减；5负脉冲；6负侧衰减；7跟踪；8锁存故障 |
| 2–5 | stageTicks,totalTicks,axisCount,decayCount | 0，拍 | 阶段、总超时和连续资格计数；TRACK阶段不再累加超时 |
| 6 | frozenAxis | 0，电角rad | 进入阶段2时冻结，两次脉冲共用同一方向 |
| 7–8 | peakP,peakN | 0，A | 相对各自静息基线的正、负电流峰值；包括脉冲后的采样峰值 |
| 9–11 | doseP,doseN,crossDose | 0，V·s | 上一实际执行区间积分，执行延迟最后一拍仍计入衰减阶段 |
| 12–13 | baselineP,baselineN | 0，A | 每次脉冲开始前的轴向电流基线 |
| 14–16 | flip,known,fault | 0，状态 | π分支、极性结论与故障锁存 |
| 17 | speedLP | 0，电角rad/s | 准入速度低通状态 |
| 18–19 | uOld | [0;0]，V | 上一实际电压区间，与当前电流对应 |

峰值差`peakP−peakN<0`时选择π翻转；差值或实际伏秒不合格时禁止形成结论。故障码：0无故障；1启动过流；2等轴线超时；3电流衰减超时；4实际电压剂量/方向不合格；5饱和对比不足；6凸极资格丢失；7非有限输入；8总超时。TRACK阶段的该模块不代替整机持续过流保护。

## 输出信号

| 端口 | 名称 | 单位 | 含义 |
|---|---|---|---|
| y1–y2 | pulse_alpha / pulse_beta | V | 仅阶段3/5输出正/负冻结轴向请求 |
| y3 | injection_scale | 1 | 等轴线及跟踪阶段请求HFI；脉冲及衰减阶段为0 |
| y4 | theta_full | 电角rad | wrap(theta_axis+π·flip_pi) |
| y5 | position_valid | 0/1 | TRACK、known、axis_valid和saliency_qualified同时成立 |
| y6–y8 | polarity_known / flip_pi / stage | 状态 | 极性锁存、分支及阶段 |
| y9–y11 | peak_positive / peak_negative / peak_difference | A | 两侧基线修正峰值与有符号差 |
| y12–y13 | dose_positive / dose_negative | V·s | 两侧实际电压积分 |
| y14 | fault_code | 枚举 | 上表故障，复位/禁能前保持 |
| y15 | frozen_axis | 电角rad | 脉冲轴方向 |
| y16 | filtered_speed | 电角rad/s | 脉冲前的速度准入观测量 |

## Scope 通道

库块本身不带Scope。组合后的实际通道见[sensorless_hfi参数说明](../../../../app_models/Sensorless/sensorless_hfi/parameter/README.md)，独立轴线台新增的校准Scope见[本目录README](README.md#scope-通道)。
