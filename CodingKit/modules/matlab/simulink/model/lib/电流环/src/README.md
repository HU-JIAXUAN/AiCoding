# dq 电流 PI 与电压限制：模型

- [CurrentControl.slx](CurrentControl.slx)：TrackingPI、VoltageLimit与新增FrameTrackingPI共用库；新PI的Compute/Update为MATLAB Function，状态由显式UnitDelay保存。
- [FrameTrackingPITest.slx](FrameTrackingPITest.slx)：坐标转换、前馈与旧PI对照测试台，6个Scope，默认50µs。
- [frame_pi_compute.m](frame_pi_compute.m)、[frame_pi_update.m](frame_pi_update.m)：与库内函数一致的源代码；[搭建脚本](../build_process/build_frame_tracking_pi.m)用于隔离目录创建/刷新候选。
- [CurrentLoopTest.slx](CurrentLoopTest.slx)：可直接运行的测试或装配模型。
- [CurrentPIProbeTest.slx](CurrentPIProbeTest.slx)：端口探路模型，无Scope；B中临时副本已生成GRT/C源码，尚未执行SIL。

库块拖入模型时保留链接，参数在调用模型工作区定义。加载回调设置工程路径及默认值；无需base workspace同名变量。

[模块入口](../README.md)

## 受保护模型

| 文件 | 来源库块 |
| --- | --- |
| [CurrentControl_FrameTrackingPIProtected.slxp](CurrentControl_FrameTrackingPIProtected.slxp) | `CurrentControl/FrameTrackingPI` |
| [CurrentControl_TrackingPIProtected.slxp](CurrentControl_TrackingPIProtected.slxp) | `CurrentControl/TrackingPI` |
| [CurrentControl_VoltageLimitProtected.slxp](CurrentControl_VoltageLimitProtected.slxp) | `CurrentControl/VoltageLimit` |

各端口、参数快照与重放结果见[发布契约](../../../../docs/interfaces/PROTECTED_MODELS.md)。
