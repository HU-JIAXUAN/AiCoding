# 正交凸极探针参数、信号和Scope

## 配置参数

入口为[hfi_probe_parameters.m](hfi_probe_parameters.m)，修改后调用[refresh_hfi_probe_parameters.m](refresh_hfi_probe_parameters.m)刷新派生向量。测试参数由[hfi_probe_test_parameters.m](hfi_probe_test_parameters.m)组合本模块的[hfi_test_parameters.m](hfi_test_parameters.m)，电机由[hfi_plant_parameters.m](hfi_plant_parameters.m)组合。重载入口为`initialize_hfi_probe_test('HFISaliencyTest')`。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e−6 | s | 采样及每段电压持续时间 |
| InjectionVoltage | 5 | V | 请求幅值；实际电压另外输入，不能用此值冒充实际值 |
| WarmupSamples | 32 | 拍 | 建立历史及初始激励，1.6 ms |
| CaptureSamples | 256 | 拍 | 回归窗口12.8 ms；两种计数均须为4的倍数 |
| MinSaliencyRatio / MaxSaliencyRatio | .08 / .8 | 1 | (λmax−λmin)/(λmax+λmin)允许范围 |
| MinInverseInductance / MaxInverseInductance | 100 / 5000 | H⁻¹ | 实测张量特征值的合理范围，不是名义Ld/Lq |
| MaxFitResidual | .2 | 1 | 未对称化回归的归一化残差上限 |
| MaxAsymmetry | .1 | 1 | 原始矩阵反对称分量/迹的上限 |
| MinVoltageRms | 1 | V | 电压差样本协方差最小特征值的RMS下限 |
| MaxCurrent | 2 | A | 探测期间αβ电流向量幅值上限；超限下一拍停止请求 |
| ProbeAxis | 0 | 定子rad | 正交激励坐标系相对α轴旋转角 |
| CrossPhase | 0 | 双电角rad | 已知交叉电感的轴向修正；未知时不能假设其偏差已消除 |
| Settings | 14元素 | 混合 | 上述字段依次打包；修改基础字段后refresh，不手改向量 |
| InitialState | zeros(19,1) | 混合 | 样本时序、历史、回归累积及故障初值 |
| 测试Duration / PlantStep | .05 / 2.5e−6 | s | 测试时长及ode4步长；其余测试字段见共用入口 |
| 测试CurrentRange / CurrentResolution / MeasurementNoise | 8 / 0 / 0 | A | ADC±8 A、默认不量化/不加噪声 |
| 测试CurrentOffset / NoiseSeed | [0;0;0] / 42 | A / 整数 | 三相偏置和局部随机种子 |
| 测试CurrentDelay / VoltageAlignmentDelay / ExecutionDelay | 0 / 0 / 0 | 拍 | 电流、观测电压年龄、执行延迟，各为0或1 |
| 测试ActuationGain | 1 | 1 | 实际施加电压/请求电压比 |
| 测试InitialElectricalAngle / MechanicalEnabled / SaturationDepth | .7 / 1 / 0 | 电角rad / 逻辑 / 1 | 仅Plant和评分；默认正常自由机械、线性磁路 |

4拍请求依次为`+axis,−axis,+orthogonal,−orthogonal`，每拍50 μs，完整序列周期200 μs。默认结束时刻为(32+256)×Ts=14.4 ms。调整窗口时同时保证测试Duration足够；测试停止太早时done不会成立。

`inverse_average`是**逆电感张量迹的一半**，单位H⁻¹；不是先平均电感再取倒数。它作为显式输入供连续HFIAxis校准使用，HFI App已完成快照交接；探针自身不自动写入其他块参数，也不替代完整启动状态机。

## 输入信号

| 名称/端口 | 单位/类型 | 来源与用途 |
|---|---|---|
| u_alpha / u_beta，u1–u2 | V，double | 采样或重建的实际执行电压；u[k]对应当前[kTs,(k+1)Ts)区间，内部存历史 |
| i_alpha / i_beta，u3–u4 | A，double | i[k]结束u[k−1]执行区间；测试台从实际电机电流经三相ADC/Clarke取得 |
| enable / reset，u5–u6 | 逻辑，double兼容 | reset优先；禁能/复位时请求和资格立即为0，状态在本拍更新清零 |

不输入真实角度、Ld或Lq。CrossPhase是可选的磁路先验，影响轴方向修正；二维张量回归及凸极差值本身不使用名义Ld/Lq。真实位置只用于测试台误差和Scope。

## 过程变量

`ProbeStates`为19元素UnitDelay，周期Ts。顺序如下：

| 元素 | 名称 | 单位/初值 | 作用 |
|---|---|---|---|
| 1 / 2 | tick / count | 拍，0 | 激励/预热时序、实际累积样本数 |
| 3–4 / 5–6 | i1 / i2 | A，[0;0] | i[k−1]、i[k−2] |
| 7–8 / 9–10 | u1 / u2 | V，[0;0] | u[k−1]、u[k−2] |
| 11–13 | XX11,XX12,XX22 | V²，0 | ∑Δu·Δuᵀ的对称部分 |
| 14–17 | YX11,YX12,YX21,YX22 | A·V/s，0 | ∑(Δ²i/Ts)·Δuᵀ |
| 18 | YY | A²/s²，0 | ∑‖Δ²i/Ts‖²，用于残差 |
| 19 | fault | 枚举，0 | 1电流超限；2输入非有限值；保持到禁能/复位 |

当前实际电压只进入Update并存为历史；请求输出仅依赖状态、active和设置，因此没有“请求电压→实际电压→同拍请求”的代数环。构建器先建立局部Mask参数作用域，再设置cfg.Ts，避免base workspace同名变量干扰；最终Mask引用调用模型工作区的probeCfg。

回归`Araw=YX/XX`，用于特征分析的是`A=(Araw+Arawᵀ)/2`。残差使用原始回归，反对称度单独检查；电压矩阵秩不足时不做除法并拒绝资格。有限Rs、低频电流变化、转动和噪声都会造成拟合误差，张量是采集窗口的近似快照。

完成或故障后停止探针请求，保持结果直到禁能/复位；完成后的电流变化不重新评价旧快照。该积木的电流检查只管理探针，不作为整机持续保护或硬件关断。

## 输出信号

| 名称/端口 | 单位/类型 | 含义 |
|---|---|---|
| injection_alpha/beta，y1–y2 | V，double | 短时正交请求；完成、禁能、复位或故障时为0 |
| theta_axis，y3 | 电角rad，double | .5atan2(2Aab,Aaa−Abb)−.5CrossPhase的包角值；仍有π歧义 |
| saliency_ratio，y4 | 1，double | 特征值差/特征值和 |
| qualified，y5 | 0/1 | 完成且激励、特征值、凸极比、残差、对称性均满足门限 |
| done，y6 | 0/1 | 采集结束或故障；done本身不表示通过 |
| inverse_average，y7 | H⁻¹ | (Aaa+Abb)/2 |
| inverse_aa / inverse_ab / inverse_bb，y8–y10 | H⁻¹ | 对称二维张量元素 |
| fit_residual，y11 | 1 | sqrt(残差能量/测量能量) |
| sample_count，y12 | 拍，double整数 | 已累积样本数；正常结束为256 |
| fault_code，y13 | 枚举double | 0无输入/电流故障，1电流超限，2非有限输入 |
| eigen_min / eigen_max，y14–y15 | H⁻¹ | 实测张量特征值 |
| quality_code，y16 | 枚举double | 0采集中，1通过，2电压激励不足/秩不足，3特征值越界，4凸极差不足，5残差大，6反对称度大，7输入/电流故障 |

qualified只表示这次快照的增量电感可分辨性。theta_axis既不包含磁极极性，也不是持续更新的运动角度；未知交叉电感仍会导致轴向偏差。采集后的转动必须由连续观测器跟踪，不能直接把快照当闭环角度。

## Scope 通道

HFISaliencyTest中每个Scope一个向量输入，按实际向量次序登记。

| Scope | 通道 | 名称 | 来源 | 单位/类型 | trace列与观察内容 |
|---|---|---|---|---|---|
| ProbeAngleScope | 1 | theta_true | Physical.y3 | 电角rad | 5，仅评估 |
| ProbeAngleScope | 2 | theta_axis | Probe.y3 | 电角rad | 12，窗口轴线快照 |
| ProbeAngleScope | 3 | error_mod_pi | AxisError | 电角rad | 26，.5wrap(2Δθ) |
| ProbeTensorScope | 1,2,3 | Aaa,Aab,Abb | Probe.y8,y9,y10 | H⁻¹ | 17,18,19，张量 |
| ProbeTensorScope | 4,5 | eigen_min,max | Probe.y14,y15 | H⁻¹ | 23,24，特征值 |
| ProbeStatusScope | 1 | qualified | Probe.y5 | 0/1 | 14，是否可用 |
| ProbeStatusScope | 2 | done | Probe.y6 | 0/1 | 15，是否结束 |
| ProbeStatusScope | 3 | fault_code | Probe.y13 | 枚举 | 22，电流/输入故障 |
| ProbeStatusScope | 4 | quality_code | Probe.y16 | 枚举 | 25，资格原因 |
| ProbeFitScope | 1 | saliency_ratio | Probe.y4 | 1 | 13，可分辨凸极差 |
| ProbeFitScope | 2 | fit_residual | Probe.y11 | 1 | 20，拟合偏差 |
| ProbeFitScope | 3 | sample_count | Probe.y12 | 拍 | 21，采集进度 |
| ProbeVoltageScope | 1,2 | actual_u_alpha,beta | ActualVoltage.y1,y2 | V | 1,2，实际作用 |
| ProbeVoltageScope | 3,4 | request_u_alpha,beta | Probe.y1,y2 | V | 10,11，请求 |
| ProbeVoltageScope | 5,6 | observed_u_alpha,beta | ObservedVoltage.y1,y2 | V | 33,34，送回归的电压年龄 |
| ProbeCurrentScope | 1,2 | measured_i_alpha,beta | ObservedCurrent.y1,y2 | A | 3,4，送回归的电流 |
| ProbeCurrentScope | 3,4 | id,iq | Physical.y6,y7 | A | 8,9，Plant真实dq，仅诊断 |
| ProbeADCScope | 1,2,3 | ia,ib,ic | MeasuredABC.y1,y2,y3 | A | 27,28,29，测得三相 |
| ProbeADCScope | 4 | i_zero | Clarke.y3 | A | 30，零序分量 |

完整38列：1–2实际uαβ；3–4测得iαβ；5真实θ；6真实ωe；7Te[N·m]；8–9真实id/iq；10–25按16个探针输出排序；26π等价轴误差；27–29测得abc；30零序；31enable；32reset；33–34观测电压；35沿用激励表的scale（本探针不用它调幅）；36负载[N·m]；37–38无ADC误差的物理iαβ。6、7、31、32、35–38仅记录，不是上述Scope的已有通道。

[模块入口](../README.md) · [搭建过程](../build_process/PROBE_BUILD.md) · [运行方法](../build_process/PROBE_USAGE.md)
