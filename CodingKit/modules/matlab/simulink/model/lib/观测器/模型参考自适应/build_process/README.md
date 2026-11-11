# 搭建过程

主要依据书12.2.2、式12.1–12.7和图12.2。过程：建立有Mask的七输入/十六输出库块；连接21状态UnitDelay、独立输出与下一状态函数；建立九列解析物理输入的测试台；连接误差、记录和Scope；编译、独立验证后保存波形。

| 文件 | 内容 |
|---|---|
| [mras_fixture.m](mras_fixture.m) | 独立连续dq电压平衡产生u/i，真实θ/ω仅供测试台评分 |
| [initialize_mras_test.m](initialize_mras_test.m) | 加载本地M配置及默认输入 |

完整步骤见[STEPS.md](STEPS.md)，运行和改参见[USAGE.md](USAGE.md)，搭建入口为[build_mras_observer.m](build_mras_observer.m)。已完成独立MIL、并行实例、从M源码重新搭建及正式路径核对；暂无另外的中间SLX。批量操作后台加载，操作完成关闭模型/图窗。

[模块入口](../README.md)
