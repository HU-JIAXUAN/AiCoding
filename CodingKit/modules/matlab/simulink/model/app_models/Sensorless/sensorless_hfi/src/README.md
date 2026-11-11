# 模型

| 文件 | 内容 |
|---|---|
| [SensorlessHFIHybrid.slx](SensorlessHFIHybrid.slx) | HFI与IPMSM EEMF独立并行、双向融合及实际FOC；12份日志、15组Scope |
| [SensorlessHFIStartup.slx](SensorlessHFIStartup.slx) | 物理PMSM、正交资格快照、HFI轴线与双脉冲极性的库链接组装；6份日志、9组Scope |
| [SensorlessHFIFOC.slx](SensorlessHFIFOC.slx) | HFI启动后接电流/速度或转矩控制、平均逆变器及锁存退出；9份日志、9组Scope |

先用独立位置模型理解资格/极性，再用FOC模型观察电流、速度与负载。再用混合模型观察撤除/恢复注入、重接分支及估算速度反转。三模型分别通过[本模块M入口](../parameter/README.md)配置。

[模块入口](../README.md)
