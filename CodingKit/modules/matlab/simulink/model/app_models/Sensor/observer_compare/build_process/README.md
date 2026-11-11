# 搭建过程

- [build_observer_compare.m](build_observer_compare.m)：先将Sensor基线另存为本模块App，通过model_edit新增监测子系统及8条输入分支，保留原控制连接。拒绝覆盖已有SLX。
- [initialize_observer_compare.m](initialize_observer_compare.m)：加载本地默认参数到模型工作区。
- [USAGE.md](USAGE.md)：信号计算、数据年龄、运行、改参、Scope和重建方法。
- [observer_diagram.png](observer_diagram.png)：实际导出的监测子系统结构。

[模块入口](../README.md)
