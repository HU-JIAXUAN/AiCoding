# 模型与算法源码

| 路径 | 内容 |
|---|---|
| [HighFrequencyObserver.slx](HighFrequencyObserver.slx) | 可复用HFIAxis、SaliencyProbe、PolarityPulse；PLL通过库链接复用AngleTracking |
| [HFIAxisTest.slx](HFIAxisTest.slx) | 物理PMSM、三相ADC、共用Clarke及采样/执行延迟测试台 |
| [HFISaliencyTest.slx](HFISaliencyTest.slx) | 正交激励、二维逆电感快照和独立凸极资格测试 |
| [hfi_probe_update.m](hfi_probe_update.m) | 实际电压/电流历史、回归累积和退出 |
| [hfi_probe_output.m](hfi_probe_output.m) | 因果请求、张量特征值和资格 |
| [hfi_polarity_update.m](hfi_polarity_update.m) | 双脉冲19状态、实际区间积分、峰值与故障锁存 |
| [hfi_polarity_output.m](hfi_polarity_output.m) | 与同拍轴线资格解耦的电压请求和极性诊断 |
| [hfi_demodulate.m](hfi_demodulate.m) | 两个实际电压区间和三个电流样本的差分解调 |
| [hfi_track_axis.m](hfi_track_axis.m) | 双角增量展开成连续轴线，仍有π歧义 |
| [hfi_measure_current.m](hfi_measure_current.m) | 测试用三相ADC夹具 |

参数从本模块[parameter](../parameter/README.md)加载；完整操作见[USAGE](../build_process/USAGE.md)。HFIAxis自身仍不输出完整位置资格；PolarityPulse与轴线组合后才形成完整角度资格，见[极性搭建](../build_process/POLARITY_BUILD.md)。HFI↔基波融合继续建设。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [HighFrequencyObserver_HFIAxisProtected.slxp](HighFrequencyObserver_HFIAxisProtected.slxp) | `HighFrequencyObserver/HFIAxis` |
| [HighFrequencyObserver_SaliencyProbeProtected.slxp](HighFrequencyObserver_SaliencyProbeProtected.slxp) | `HighFrequencyObserver/SaliencyProbe` |

各端口、参数快照与重放结果见[发布契约](../../../../../docs/interfaces/PROTECTED_MODELS.md)。
