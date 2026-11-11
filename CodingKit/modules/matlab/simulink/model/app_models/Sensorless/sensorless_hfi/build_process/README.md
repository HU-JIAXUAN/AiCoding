# 搭建过程

| 文件 | 内容 |
|---|---|
| [HYBRID_BUILD.md](HYBRID_BUILD.md) | 书5.9的双跟踪器位置融合、控制接线与因果状态 |
| [HYBRID_USAGE.md](HYBRID_USAGE.md) | 混合模型运行、M参数、分批验证及Scope使用 |
| [build_hfi_hybrid.m](build_hfi_hybrid.m) | 从原HFI低速FOC重新装配，拒绝覆盖目标 |
| [initialize_hfi_hybrid.m](initialize_hfi_hybrid.m)、[hfi_hybrid_workspace.m](hfi_hybrid_workspace.m) | 加载/组合本模块M参数与模型工作区 |
| [hfi_hybrid_stimulus.m](hfi_hybrid_stimulus.m) | 11列采样输入 |
| [STEPS.md](STEPS.md) | 探针快照、HFI校准、极性、重新锁定和因果时序 |
| [USAGE.md](USAGE.md) | 运行、M文件配置、SimulationInput及Scope观察顺序 |
| [build_hfi_startup.m](build_hfi_startup.m) | 用model_edit从库链接搭建App；拒绝覆盖已有模型 |
| [initialize_hfi_startup.m](initialize_hfi_startup.m) | 添加依赖路径并加载本模块配置到模型工作区 |
| [hfi_startup_stimulus.m](hfi_startup_stimulus.m) | 7列采样刺激表和局部随机种子 |
| [FOC_BUILD.md](FOC_BUILD.md) | 闭环分层、回算位置、参考清状态及两处实际修正 |
| [FOC_USAGE.md](FOC_USAGE.md) | 闭环运行、改M参数和读波形 |
| [build_hfi_foc.m](build_hfi_foc.m) | 从库链接搭建完整HFI低速FOC，空白目录复现已核对 |
| [initialize_hfi_foc.m](initialize_hfi_foc.m) | 加载闭环工作区配置及本地M参数 |
| [hfi_foc_stimulus.m](hfi_foc_stimulus.m) | 10列命令/测量/负载刺激表 |

[模块入口](../README.md)
