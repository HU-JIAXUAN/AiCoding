# VF_Control 示例核对

[原始示例](VF_Control.slx)保留。原模型主链为 Ramp → Freq2Theta → InvPark → SVPWM → Average-Value Inverter → Surface PMSM。Freq2Theta 内部角度增量含 `TS*2*pi/60*Freq`，不能直接把原始 Freq 当成 Hz；幅值近似 `clamp(6.8*Freq,2,24/sqrt(3))`，Ramp 初值 15 已把该幅值推到约 13.86 V。原角度逻辑只对正向越过 2π 折返。

新 App 采用相同的旋转电压到逆变器主链，将输入明确为电频率 Hz，用 2πTsfc 推角并支持正反转折返。幅值采用磁链斜率、低频补偿、幅值斜率与实际母线限幅；加上启动观察、零频对齐及过流保护。新旧电机参数不同，不做数值复刻。

本次读取了示例接线与参数；原模型存在外部电机参数文件路径及 `mcbplantlib` 依赖，未把其仿真计入本 App 验收。
