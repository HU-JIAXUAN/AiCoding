# 搭建与运行

| 文件 | 作用 |
|---|---|
| [STEPS.md](STEPS.md) | 按输入、对象、观测、分配、执行、互锁说明搭建 |
| [USAGE.md](USAGE.md) | 打开、修改参数、运行、Scope和复现命令 |
| [build_sensorless_fw.m](build_sensorless_fw.m) | 从正式EEMF App另存新模型，用model_edit组装；拒绝覆盖已有SLX |
| [add_fw_start_interlock.m](add_fw_start_interlock.m) | 添加仅使用估算EMF的启动互锁 |
| [tidy_sensorless_fw_model.m](tidy_sensorless_fw_model.m) | 只整理本次新App，各子系统先于根图 |
| [initialize_sensorless_fw.m](initialize_sensorless_fw.m) | 重载本模块M参数到本模型工作区 |
| [inspect_sensorless_fw.m](inspect_sensorless_fw.m) | 编译核对Scope宽度、根图连接和库链接；先关闭此App再运行 |
| [sensorless_fw_stimulus.m](sensorless_fw_stimulus.m) | 生成7列可修改工况 |
| [run_sensorless_fw_case.m](run_sensorless_fw_case.m) | 用SimulationInput运行、解析六组数据并关闭本次加载的模型 |
| [fw_app_diagram.png](fw_app_diagram.png) | 根图 |
| [fw_controller_diagram.png](fw_controller_diagram.png) | 控制与电流分配 |
| [fw_plant_diagram.png](fw_plant_diagram.png) | 物理桥对象及离线真值测量 |
| [fw_voltagestage_diagram.png](fw_voltagestage_diagram.png) | 实际母线归一化及SVPWM/执行延迟 |
| [fw_startinterlock_diagram.png](fw_startinterlock_diagram.png) | 启动许可、观察计数及复位 |

[模块](../README.md) · [推导](../docs/公式推导.md)
