# 速度PI、位置P与离散速度给定：搭建过程

- [STEPS.md](STEPS.md)：计算、状态更新、连接顺序和实际模型图。
- [USAGE.md](USAGE.md)：原Position/Speed运行、调参和读波形。
- [PROFILE_BUILD.md](PROFILE_BUILD.md)：SpeedProfile的离散方程、复位实现及运行方法。
- [build_speed_profile.m](build_speed_profile.m)：向原库追加SpeedProfile并生成独立测试台。
- [initialize_speed_profile_test.m](initialize_speed_profile_test.m)：刷新本测试台工作区参数。
- [speed_profile_stimulus.m](speed_profile_stimulus.m)：构造reference/enable/reset刺激表。
- [test_diagram.png](test_diagram.png)：测试/装配模型导出图。
- [library_diagram.png](library_diagram.png)：库接口图。

[模块入口](../README.md)
