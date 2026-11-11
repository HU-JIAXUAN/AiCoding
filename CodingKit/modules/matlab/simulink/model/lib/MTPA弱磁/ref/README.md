# 参考资料

| 资料 | 来源 |
|---|---|
| PMSM MTPA与弱磁原理，电流圆/电压约束 | https://www.mathworks.com/help/mcb/gs/field-weakening-control-mtpa-pmsm.html |
| MTPA Control Reference官方块，参数与坐标约定 | https://www.mathworks.com/help/mcb/ref/mtpacontrolreference.html |
| 工程PMSM模型与参数定义 | [永磁同步电机](../../永磁同步电机/README.md) |
| 原电流/时序/整机装配实现 | [experiment搭建记录](../../../app_models/Sensor/experiment/build_process/STEPS.md) |
| 本工程此前chensha/MBD参考核对 | [REFERENCE_06_14.md](../../../../docs/references/REFERENCE_06_14.md) |

核对日期2026-11-08。以上官方资料用于公式与约定核对；本模块使用基础Simulink块，没有直接封装Motor Control Blockset的MTPA块。弱磁采用带模型需求辅助的有界积分策略，不声称与官方CVCP/VCLMT逐点等价。在线资料可能展示新版本界面，本地模型实测环境为R2026a。

本次没有复制外部demo进工程。[公式与实现边界](../build_process/DESIGN.md) · [模块入口](../README.md)
