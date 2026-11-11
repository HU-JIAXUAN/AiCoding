# 搭建过程

| 文件 | 内容 |
|---|---|
| [build_sensorless_handover.m](build_sensorless_handover.m) | 用model_edit建立库、状态存储和测试台，拒绝覆盖源模型 |
| [initialize_handover_test.m](initialize_handover_test.m) | 安装本模块配置和11列合成测试输入 |
| [STEPS.md](STEPS.md) | 状态、捕获、平滑权重、相位突跳和复位实现 |
| [USAGE.md](USAGE.md) | 运行、参数覆盖、单工况与完整验证 |
| [algorithm_diagram.png](algorithm_diagram.png) | 实际库内部结构 |
| [test_diagram.png](test_diagram.png) | 原Handover独立测试台 |
| [build_hybrid_fusion.m](build_hybrid_fusion.m) | 在原库追加HybridFusion并生成独立台，全程隐藏窗口 |
| [initialize_hybrid_fusion_test.m](initialize_hybrid_fusion_test.m) | 加载融合配置、工况和测试刺激 |
| [hybrid_fusion_stimulus.m](hybrid_fusion_stimulus.m) | 解析两路估计及独立评估角/速度 |
| [FUSION_BUILD.md](FUSION_BUILD.md) | 书5.9对应、资格、包角、π重接、注入及显式状态 |
| [FUSION_USAGE.md](FUSION_USAGE.md) | 运行、M参数覆盖与Scope观察方法 |
