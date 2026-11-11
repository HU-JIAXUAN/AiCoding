# 搭建过程

[build_mit_joint_control.m](build_mit_joint_control.m) 以现有 [MotorExperiment.slx](../../Sensor/experiment/src/MotorExperiment.slx) 为装配模板，保留库链接。在其电流参考入口并接 MIT 支路，模型搭建使用 Simulink Agentic Toolkit 的 `model_edit`。

需要重建时，将本目录加入 MATLAB 路径，调用 `build_mit_joint_control(fullfile(outputDirectory,'MitJointControl.slx'))`。使用空目录输出候选文件。正式模型位于 [src](../src/README.md)，加载回调使用 [initialize_mit_joint_control.m](initialize_mit_joint_control.m)。
