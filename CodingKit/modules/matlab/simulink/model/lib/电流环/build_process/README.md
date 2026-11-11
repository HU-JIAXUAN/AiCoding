# dq 电流 PI 与电压限制：搭建过程

- [STEPS.md](STEPS.md)：原PI计算、状态更新、连接顺序和实际模型图。
- [FRAME_TRACKING.md](FRAME_TRACKING.md)：新增坐标跟踪PI的状态、公式、搭建、运行、调参、Scope、重建与模型图。
- [build_frame_tracking_pi.m](build_frame_tracking_pi.m)：隔离目录候选生成/源函数刷新；[initialize_frame_pi_test.m](initialize_frame_pi_test.m)管理新测试默认模型工作区。
- [USAGE.md](USAGE.md)：界面运行、调参、独立输入、批量验证与读波形。
- [test_diagram.png](test_diagram.png)：测试/装配模型导出图。
- [library_diagram.png](library_diagram.png)：库接口图。

[模块入口](../README.md)
