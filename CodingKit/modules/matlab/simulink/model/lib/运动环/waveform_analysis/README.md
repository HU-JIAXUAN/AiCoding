# 速度PI、位置P与离散速度给定：波形与验证

- [run_motion_loop_validation.m](run_motion_loop_validation.m)：3个工况入口。
- [ANALYSIS.md](ANALYSIS.md)：波形解释和范围。
- `results.mat`（运行验证后生成）：records包含参数、输入、trace、通道名和指标。
- [metrics.json](metrics.json)：实际通过结果与指标。
- [summary.png](summary.png) / [summary.svg](summary.svg)：代表工况。

- [run_speed_profile_validation.m](run_speed_profile_validation.m)：新增8项独立给定测试。
- [PROFILE_ANALYSIS.md](PROFILE_ANALYSIS.md)：限速、斜率和清状态的验收区别。
- `profile_results.mat`（运行验证后生成） / [profile_metrics.json](profile_metrics.json)：8项原始记录与结果。
- [profile_verification.json](profile_verification.json)：受测文件哈希、重新搭建、正式路径核对及原3项回归。
- [profile_clearing.svg](profile_clearing.svg) / [profile_clearing.png](profile_clearing.png)：禁能、重新使能和复位。

[模块入口](../README.md)
