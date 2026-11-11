# 无位置反馈启动序列与I-f软件场角：文档入口

[公式推导.md](公式推导.md)说明原理、公式、量纲、离散状态与实际实现的对应。

| 文件 | 用途 |
|---|---|
| [SensorlessStartup.slx](../src/SensorlessStartup.slx) | 可复用库 |
| [SensorlessStartupTest.slx](../src/SensorlessStartupTest.slx) | 验证模型 |
| [参数、信号和Scope通道](../parameter/README.md) | 本模块维护入口 |
| [搭建过程与运行入口](../build_process/README.md) | 本模块维护入口 |
| [数据、波形和验证结果](../waveform_analysis/README.md) | 本模块维护入口 |
| [参考来源](../ref/README.md) | 本模块维护入口 |

[模块README](../README.md)

## OpenLoopDrive 持续开环命令

同一份[推导](公式推导.md#openloopdrive-持续开环命令)说明 I-f/V/f 共用的软件角度、观察、对齐和幅值。具体物理 App 的电流环或电压律分别在 [I-f](../../../app_models/Sensorless/sensorless_if/docs/README.md) 和 [V/f](../../../app_models/Sensorless/sensorless_vf/docs/README.md)。
