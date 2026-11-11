# 模型和算法源文件

- [SensorlessStartup.slx](SensorlessStartup.slx)：可复用Startup库块，四个输入、八个输出；Unit Delay保存五个状态。
- [SensorlessStartupTest.slx](SensorlessStartupTest.slx)：From Workspace驱动独立测试台，五组Scope、12列trace，可直接Run。
- [startup_step.m](startup_step.m)：SequenceStep的MATLAB Function源。搭建脚本将其导入SLX；修改源后须同步函数块并重新验证。

[模块入口](../README.md) · [运行方法](../build_process/USAGE.md)

## 开环命令组

- [OpenLoopDrive.slx](OpenLoopDrive.slx)：库内 `Reference` 为复用接口（App 中实例名为 Command），状态由 Unit Delay 持有。
- [OpenLoopDriveTest.slx](OpenLoopDriveTest.slx)：人工输入下独立验证，按 [Scope 表](../parameter/OPEN_LOOP_PARAMETERS.md)观察。
- [状态更新](open_loop_drive_update.m)与[状态读出](open_loop_drive_output.m)：构建脚本注入对应 MATLAB Function；修改 M 后需要重建这一组。

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [OpenLoopDriveProtected.slxp](OpenLoopDriveProtected.slxp) | `OpenLoopDrive/Reference` |
| [SensorlessStartupProtected.slxp](SensorlessStartupProtected.slxp) | `SensorlessStartup/Startup` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
