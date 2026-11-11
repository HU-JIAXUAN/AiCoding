# 搭建过程

| 记录 | 作用 |
|---|---|
| [STEPS.md](STEPS.md) | 块结构、离散更新与复位说明 |
| [USAGE.md](USAGE.md) | Run、调参和波形操作 |
| [build_angle_tracking.m](build_angle_tracking.m) | 用 model_edit 重建库和测试台 |
| [initialize_angle_tracking_test.m](initialize_angle_tracking_test.m) | 安装模型工作区默认值 |
| [build_pll_instances.m](build_pll_instances.m) | 重建两实例独立参数测试模型 |
| [initialize_pll_instances.m](initialize_pll_instances.m) | 为实例测试安装pllA/pllB，覆盖增益和初值 |
| [instances_diagram.png](instances_diagram.png) | 两实例实际连接图 |

重建脚本需要 R2026b、Simulink Agentic Toolkit。脚本拒绝覆盖已有源模型；正常运行测试不需要重新搭建。模型已生成：[PLL内部图](pll_diagram.png)、[独立测试台](test_diagram.png)。
