# 完整App算法：按位置反馈分类

App先按是否使用转子位置反馈分类，再在分类目录下按功能划分。两类App共用[model/lib](../lib/README.md)的积木。

可复用观测器也归lib；Sensor可调用它做并行估算，Sensorless用估算量控制。新增模型清单与顺序见[无位置传感器计划](../../docs/plans/SENSORLESS_PLAN.md)，六类基波/启动库、HFI及Sensor并行对照、SMO/HFI低速闭环已创建，高低速融合18项物理MIL已完成，扩展观测器按计划继续推进。

| 分类 | 闭环角度/速度来源 | 当前内容 |
|---|---|---|
| [Sensor](Sensor/README.md) | 位置/速度反馈；当前为仿真反馈链 | experiment、mtpa_fw、observer_compare |
| [Sensorless](Sensorless/README.md) | 观测器或其他估算算法 | sensorless_foc（三份启动24项、带速13项、扩展40项）；sensorless_hfi（启动22项、低速24项、融合18项）；sensorless_fw（16项含2反例） |

分类依据是参与控制的角度/速度来源。对象真实角度仅用于监测或误差对照时，不因此归入Sensor。电流采样拓扑在各App中单独说明。

各功能App保留README、src、parameter、build_process、waveform_analysis和ref，模型放src。App模型本身用于运行，名称不带Test后缀；模块独立验证模型留在lib并以Test结尾。公共初始化与测试入口在[docs/scripts](../../docs/scripts/README.md)。

[返回model](../README.md)
