# 使用转子位置反馈的App

本目录按功能存放使用位置/速度反馈参与控制的完整App。当前三个App均使用仿真反馈链，尚未接入真实编码器、旋变或位置霍尔。

| App | 模型 | 当前范围 |
|---|---|---|
| [experiment](experiment/README.md) | [MotorExperiment.slx](experiment/src/MotorExperiment.slx) | 电流/速度/位置整机基线，52列记录 |
| [mtpa_fw](mtpa_fw/README.md) | [MTPAFWMotor.slx](mtpa_fw/src/MTPAFWMotor.slx) | 转矩PI及MTPA/FW分配，74列记录 |
| [observer_compare](observer_compare/README.md) | [SensorObserverCompare.slx](observer_compare/src/SensorObserverCompare.slx) | SMO并行估算，原控制52列+监测28列，8项MIL |

三个App继续引用[lib](../../lib/README.md)中的同一套通用积木。每个App维护自己的src、parameter、build_process、waveform_analysis和ref；公共测试入口在[docs/scripts](../../../docs/scripts/README.md)。

observer_compare已完成SMO并行估算：控制仍采用位置反馈，估算值只与同年龄反馈对照，所以归Sensor。观测器本体仍在lib，步骤见[无位置传感器计划](../../../docs/plans/SENSORLESS_PLAN.md)。

[App分类](../README.md) · [Sensorless](../Sensorless/README.md)
