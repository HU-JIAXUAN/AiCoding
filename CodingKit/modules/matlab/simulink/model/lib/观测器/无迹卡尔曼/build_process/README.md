# UKF搭建与运行

| 文件 | 内容 |
|---|---|
| [STEPS.md](STEPS.md) | 校正/预测时序、sigma点、角度统计、协方差、资格与故障 |
| [USAGE.md](USAGE.md) | 直接Run、M参数覆盖、批量验证和Scope |
| [build_ukf_observer.m](build_ukf_observer.m) | 新建库/Test，引用共享Measurement，构建时不覆盖现有SLX |
| [initialize_ukf_paths.m](initialize_ukf_paths.m) | 本模块与兄弟EKF/Plant路径 |
| [initialize_ukf_test.m](initialize_ukf_test.m) | 本地参数和独立9列轨迹 |

从M源在独立兄弟目录重新搭建成功，默认50列与正式路径数据相同；内嵌Predict、共享校正来源及库链接已核对。暂无过程SLX，过程由构建M和上述文档保存。批量操作不打开编辑器/Scope，结束后关闭本次模型与图窗。

[模块入口](../README.md)
