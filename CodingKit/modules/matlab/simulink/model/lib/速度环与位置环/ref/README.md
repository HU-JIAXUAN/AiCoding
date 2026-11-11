# 速度PI、位置P与离散速度给定：参考

| 资料 | 来源 |
|---|---|
| [MathWorks官方资料](https://www.mathworks.com/help/mcb/ug/design-field-oriented-control-algorithm.html) | https://www.mathworks.com/help/mcb/ug/design-field-oriented-control-algorithm.html |
| [本次参考核对](../../../../docs/references/REFERENCE_06_14.md) | chensha只读SLX/XML；MBD辅助背景 |
| [接口约定](../../../../docs/interfaces/INTERFACE_CONTRACT.md) | 工程量纲、方向、时基和限制语义 |

SpeedProfile来自[HFI闭环](../../../app_models/Sensorless/sensorless_hfi/README.md)禁能重启试验发现的旧给定状态问题。离散斜率按物理单位乘Ts实现，禁能/复位显式写0；过程与反例见[搭建记录](../build_process/PROFILE_BUILD.md)。

本模块使用基础块及本工程库，没有复制或修改外部demo；没有宣称与原始demo或官方块逐点等价。

[模块入口](../README.md)
