# 搭建过程

主要书籍12.4.1–12.4.3，印刷315–317/PDF344–346，式12.31–12.44。先建立共用线性电流测量校正，再通过28保持量和Euler/Jacobian预测组成EKF，独立轨迹只接u/i及控制命令。

| 文件 | 作用 |
|---|---|
| [initialize_ekf_paths.m](initialize_ekf_paths.m) | 添加本模块及共用过程/输入生成器路径 |
| [initialize_ekf_test.m](initialize_ekf_test.m) | 本地M配置和独立输入 |

[STEPS.md](STEPS.md)说明四状态、测量/预测时序、28保持量、资格及故障；[USAGE.md](USAGE.md)说明运行、调参和日志。重建入口为[build_ekf_observer.m](build_ekf_observer.m)。

两个SLX已完成；从独立兄弟目录M源重新搭建，默认50列及时间与正式数据一致。没有另存过程SLX，过程以构建M源及上述文档记录。批量操作不打开编辑器或Scope。

[模块入口](../README.md)
