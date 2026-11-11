# 搭建过程

| 文件 | 内容 |
|---|---|
| [STEPS.md](STEPS.md) | 状态方程、滑模注入、LPF 相移和方向处理 |
| [USAGE.md](USAGE.md) | Run、修改参数和观察 Scope |
| [build_sliding_mode_observer.m](build_sliding_mode_observer.m) | R2026b model_edit 搭建脚本 |
| [initialize_smo_test.m](initialize_smo_test.m) | 模型工作区初始化 |
| [smo_fixture.m](smo_fixture.m) | 独立连续 SPMSM 方程生成测试输入 |
| [SIGMOID_STEPS.md](SIGMOID_STEPS.md) | 平滑注入、4状态、方向/故障及库/Test连接 |
| [SIGMOID_USAGE.md](SIGMOID_USAGE.md) | 默认Run、本地M调参、批量入口与6组Scope |
| [build_sigmoid_smo.m](build_sigmoid_smo.m) | 独立库和Test的完整model_edit搭建脚本 |
| [initialize_sigmoid_smo_paths.m](initialize_sigmoid_smo_paths.m) / [initialize_sigmoid_smo_test.m](initialize_sigmoid_smo_test.m) | 模块路径与Test工作区初始化 |

暂无中间过程SLX；步骤和完整可复现脚本保存在本目录。已保存[SMO内部图](smo_diagram.png)和[独立测试台](test_diagram.png)。
