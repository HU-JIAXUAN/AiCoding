# OpenLoopDrive 搭建与运行

1. 将六路输入组成向量，配置 `openLoopCfg.Vector`；`Update` 计算下一拍状态，`State` 用 Unit Delay 持有。
2. `ReadState` 只用当前状态、使能、复位和配置，采样电流与电压没有直接通路到门极输出。这样接回对象时不会引入代数环；复位和禁能的门极禁止仍立即生效。
3. 在 OpenLoopDriveTest 链接 Reference，接入六列人工工况，分出 Scope 和十四列记录。用参数 M 切换 I-f、V/f 和边界输入。

在工程根目录运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'))
initialize_motor_paths
open_system('OpenLoopDriveTest')
```

运行后手动打开 Scope。改测试默认参数后执行 `initialize_open_loop_drive_test('OpenLoopDriveTest')`。批量验证先把本模块 `waveform_analysis` 加到路径，再执行 `run_open_loop_drive_validation()`。重建时先关闭本组模型，再执行 `build_open_loop_drive()`。
