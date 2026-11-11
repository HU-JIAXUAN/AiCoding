# 模型

[MitJointControl.slx](MitJointControl.slx) 是单关节应用。双击打开后，模型回调加载参数和库路径。选择器 `SelectDCurrent`、`SelectQCurrent` 后只有一个 `CurrentStage`。现有电流、位置、速度和转矩 Scope 保留，关节侧诊断量记录到 `mitTrace`。回到[应用入口](../README.md)。

从 MATLAB 命令行运行工程的 `initialize_motor_paths` 后，也可以用 `open_system('MitJointControl')` 打开。
