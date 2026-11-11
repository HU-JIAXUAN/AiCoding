# App模型

[SensorlessFieldWeakeningFOC.slx](SensorlessFieldWeakeningFOC.slx)是直接运行的完整算法App，不带Test后缀。模型在R2026b构建，调用20个现有库链接；库源仍在`model/lib`。

打开模型时PostLoadFcn调用本模块[初始化](../build_process/initialize_sensorless_fw.m)。从[运行说明](../build_process/USAGE.md)设置工程路径后打开此文件。输入从模型工作区`testStim`读取，结果由六组To Workspace保存；29组Scope通道在[参数页](../parameter/README.md)。

[模块](../README.md) · [公式](../docs/公式推导.md)
