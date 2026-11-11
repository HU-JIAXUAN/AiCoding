# PMSM 数学电机与刚性负载：搭建过程

- [STEPS.md](STEPS.md)：计算、状态更新、连接顺序和实际模型图。
- [USAGE.md](USAGE.md)：界面运行、调参、独立输入、批量验证与读波形。
- [test_diagram.png](test_diagram.png)：测试/装配模型导出图。
- [library_diagram.png](library_diagram.png)：库接口图。

高频/饱和对象：[HF_BUILD.md](HF_BUILD.md)说明磁链、增量电感和机械耦合；[HF_USAGE.md](HF_USAGE.md)说明运行与调参；[build_hf_pmsm_plant.m](build_hf_pmsm_plant.m)、[initialize_hf_plant_test.m](initialize_hf_plant_test.m)和[hf_plant_stimulus.m](hf_plant_stimulus.m)保存构建、加载和脉冲生成。[测试台图](hf_test_diagram.png)与[库图](hf_library_diagram.png)来自正式模型。

[spmsm_estimation_fixture.m](spmsm_estimation_fixture.m)是EKF/后续UKF的独立连续dq轨迹输入，不调用离散过程或Jacobian。过程方程和参数见[说明](../parameter/SENSORLESS_PARAMETERS.md)，完整观测器运行见[EKF教程](../../观测器/扩展卡尔曼/build_process/USAGE.md)。

桥耦合对象：[BRIDGE_BUILD.md](BRIDGE_BUILD.md)、[BRIDGE_USAGE.md](BRIDGE_USAGE.md)分别记录三状态桥/电机耦合和运行方法；[构建脚本](build_pmsm_bridge_plant.m)、[初始化](initialize_bridge_test.m)、[工况生成](bridge_plant_stimulus.m)、[运行器](run_bridge_case.m)均保存在本模块。

运行时母线：[BRIDGE_BUS_BUILD.md](BRIDGE_BUS_BUILD.md)、[BRIDGE_BUS_USAGE.md](BRIDGE_BUS_USAGE.md)记录新4输入对象；[构建](build_pmsm_bridge_bus.m)、[初始化](initialize_bridge_bus_test.m)、[输入生成](bridge_bus_stimulus.m)、[运行器](run_bridge_bus_case.m)、[布局](tidy_bridge_bus_models.m)与[原生核对](inspect_bridge_bus_models.m)均在本目录。

[模块入口](../README.md)
