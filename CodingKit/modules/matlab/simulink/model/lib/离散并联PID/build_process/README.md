# DiscretePID 搭建过程

| 文件 | 内容 |
|---|---|
| [DESIGN.md](DESIGN.md) | 单拍计算、状态与复位定义 |
| [STEPS.md](STEPS.md) | 实际步骤、块连接、求解器、测试问题及修正 |
| [USAGE.md](USAGE.md) | 界面运行、单次调参、输入构造、Scope 操作与批量测试 |
| [initialize_discrete_pid_test.m](initialize_discrete_pid_test.m) | 设置测试模型工作区默认参数与输入 |
| [controller_diagram.png](controller_diagram.png) | 库模块顶层实际模型图 |
| [output_stage_diagram.png](output_stage_diagram.png) | 输出计算内部实际模型图 |
| [integral_update_diagram.png](integral_update_diagram.png) | 积分更新内部实际模型图 |
| [derivative_filter_diagram.png](derivative_filter_diagram.png) | 滤波微分内部实际模型图 |
| [test_diagram.png](test_diagram.png) | 独立测试模型实际模型图 |

最终模型在 [src/](../src/README.md)。本次直接创建首版模型，没有另存中间过程模型。

[返回模块](../README.md)
