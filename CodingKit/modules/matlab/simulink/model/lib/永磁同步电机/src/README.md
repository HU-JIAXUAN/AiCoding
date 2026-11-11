# PMSM 数学电机与刚性负载：模型

- [PMSMPlant.slx](PMSMPlant.slx)：可复用库，双击子系统查看基础块。
- [PMSMPlantTest.slx](PMSMPlantTest.slx)：可直接运行的测试或装配模型。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

新增[PMSMHighFrequencyPlant.slx](PMSMHighFrequencyPlant.slx)与[PMSMHighFrequencyPlantTest.slx](PMSMHighFrequencyPlantTest.slx)；[pmsm_hf_dynamics.m](pmsm_hf_dynamics.m)为内嵌连续物理方程；[pmsm_hf_output.m](pmsm_hf_output.m)只从状态计算测量输出，避免当前电压到电流测量的人工直接馈通。高频对象通过独立Mask参数实例化，电机真实角度只由内部状态产生。

共用估计过程：[pmsm_sensorless_step.m](pmsm_sensorless_step.m)返回四状态Euler映射及A，[pmsm_sensorless_measurement.m](pmsm_sensorless_measurement.m)返回电流测量及H。两个纯函数不持有状态；输入/单位见[过程参数](../parameter/SENSORLESS_PARAMETERS.md)。

新增[PMSMBridgePlant.slx](PMSMBridgePlant.slx)与[PMSMBridgePlantTest.slx](PMSMBridgePlantTest.slx)，库导出BridgeMotor。源为[pmsm_bridge_step.m](pmsm_bridge_step.m)和[pmsm_bridge_output.m](pmsm_bridge_output.m)；[接口/采样年龄](../parameter/BRIDGE_PARAMETERS.md)说明当前电流与隐式区间诊断的区别。

桥模型的Step/Measure内嵌了src中的计算函数；修改计算M源后需在独立副本重建SLX，直接改M源不会自动更新内嵌代码。参数M文件则可通过初始化/运行器重新加载，无需重建。

新增[PMSMBridgeBusPlant.slx](PMSMBridgeBusPlant.slx)/[PMSMBridgeBusPlantTest.slx](PMSMBridgeBusPlantTest.slx)，导出BridgeBusMotor，增加第4输入bus_voltage。仅[bridge_bus_settings.m](bridge_bus_settings.m)替换配置向量第9项；Step/Measure仍取现有物理M源。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [PMSMBridgeBusPlantProtected.slxp](PMSMBridgeBusPlantProtected.slxp) | `PMSMBridgeBusPlant/BridgeBusMotor` |
| [PMSMBridgePlantProtected.slxp](PMSMBridgePlantProtected.slxp) | `PMSMBridgePlant/BridgeMotor` |
| [PMSMHighFrequencyPlantProtected.slxp](PMSMHighFrequencyPlantProtected.slxp) | `PMSMHighFrequencyPlant/HFPMSM` |
| [PMSMPlant_ElectricalProtected.slxp](PMSMPlant_ElectricalProtected.slxp) | `PMSMPlant/Electrical` |
| [PMSMPlant_MechanicalProtected.slxp](PMSMPlant_MechanicalProtected.slxp) | `PMSMPlant/Mechanical` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
