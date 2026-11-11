# 搭建过程

| 文件 | 内容 |
|---|---|
| [build_sensorless_startup.m](build_sensorless_startup.m) | model_edit创建库、状态存储和测试台；拒绝覆盖源模型 |
| [initialize_startup_test.m](initialize_startup_test.m) | 加载本模块路径、配置和四列测试输入 |
| [STEPS.md](STEPS.md) | 状态与离散实现说明 |
| [USAGE.md](USAGE.md) | Run、参数覆盖、Scope与验证入口 |
| [algorithm_diagram.png](algorithm_diagram.png) | 实际库内部结构 |
| [test_diagram.png](test_diagram.png) | 实际独立测试模型 |

## OpenLoopDrive

[搭建过程与使用](OPEN_LOOP_BUILD.md) · [构建 M](build_open_loop_drive.m) · [Test 初始化 M](initialize_open_loop_drive_test.m)
