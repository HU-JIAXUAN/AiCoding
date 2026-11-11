# 搭建过程

| 文件 | 内容 |
|---|---|
| [STEPS.md](STEPS.md) | 磁链方程、泄漏/直流状态、离散频率补偿、PLL/有效性及复位时序 |
| [USAGE.md](USAGE.md) | GUI与脚本运行、M文件参数刷新、单次覆盖及读取已有数据 |
| [build_flux_observer.m](build_flux_observer.m) | 通过model_edit重建库和测试台；已有模型时拒绝覆盖 |
| [initialize_flux_test.m](initialize_flux_test.m) | 本模块M文件到模型工作区及独立输入轨迹 |
| [test_diagram.png](test_diagram.png) | 正式测试台及七组Scope |

候选模型在隔离目录完成24项MIL后按SHA256迁入src，正式路径重新加载/默认运行通过。Compute内嵌源码与src/flux_compute.m一致，ready标志使用与状态相同的数值类型。主要书籍章节及与书中图3.4的区别见[参考页](../ref/README.md)。

[模块入口](../README.md)
