# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》2.2.1，印刷25–26 / PDF54–55；3.2，印刷42–46 / PDF71–75：SPMSM磁链、未知初值、漂移和滤波相位误差 | [原文件、章节及采用说明](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| SPMSM电压模型磁链与低通积分、直流偏置处理 | https://www.mathworks.com/help/mcb/ref/fluxobserver.html |
| 共用相位PLL | [相位跟踪](../../../相位跟踪/README.md) |
| 测试使用的独立轨迹 | [emf_fixture.m](../../反电势/build_process/emf_fixture.m) |

本模块的离散滤波补偿为自行推导，与书中图3.4的幅值反馈方法不同；24项独立MIL及处理开关反例见[波形分析](../waveform_analysis/ANALYSIS.md)。

[模块入口](../README.md)
