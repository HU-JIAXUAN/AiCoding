# OpenLoopDrive 波形分析

| 核对项 | 条件 |
| --- | --- |
| 模型 | [OpenLoopDriveTest](../src/OpenLoopDriveTest.slx)，只测命令，不含对象 |
| 参数 | [默认命令](../parameter/open_loop_drive_parameters.m)与[加速测试工况](../parameter/open_loop_drive_test_parameters.m) |
| 采样 | 测试参数中 ValidationTs，日志同周期 |
| 求解器 | 固定步长离散 |
| 工况 | 正反 I-f/V/f、限频、限压、观察拒绝、过流、禁能/复位、非法频率/母线和零频 |
| 数据 | [open_loop_metrics.json](open_loop_metrics.json)，5 组 Scope 可复跑观察，无新增 MAT |

13 项独立 MIL 通过。阶段波形先观察、再对齐、再运行；反转时软件频率和角增量随符号改变；过流或观察超时关闭门极。端电压高的反例不允许盲目对齐。真实对象能否同步见两个整机 App 的独立结果。
