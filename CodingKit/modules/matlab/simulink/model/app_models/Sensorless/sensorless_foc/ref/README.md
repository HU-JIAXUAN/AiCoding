# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》2.5、3.2、5.9；lib/App连接与理想电压边界 | [原文件、页码与采用说明](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| [无位置计划](../../../../../docs/plans/SENSORLESS_PLAN.md) | 本工程SL01–SL09 |
| [Sensor并行对照](../../../Sensor/observer_compare/README.md) | 已验证的SPMSM估算及年龄关系 |
| [启动](../../../../lib/无感启动/README.md)、[接管](../../../../lib/无感切换/README.md) | 共用lib |
| [坐标PI](../../../../lib/电流环/build_process/FRAME_TRACKING.md)、[参考混合](../../../../lib/math/build_process/FRAME_BLEND.md) | 共用lib的状态/坐标处理 |
| To Workspace采样与数据格式 | https://www.mathworks.com/help/simulink/slref/toworkspace.html |
| Rate Transition参数和速率处理 | https://www.mathworks.com/help/simulink/slref/ratetransition.html |
| 控制任务的速率交接 | https://www.mathworks.com/help/simulink/ug/handle-rate-transitions.html |

新App分别链接[EMF/EEMF库](../../../../lib/观测器/反电势/README.md)和[磁链库](../../../../lib/观测器/磁链/README.md)。推导见两库的[EMF公式](../../../../lib/观测器/反电势/docs/公式推导.md)、[磁链公式](../../../../lib/观测器/磁链/docs/公式推导.md)，以及本模块[组合公式](../docs/公式推导.md)。主要书籍的章节/页码及采用边界仍由[书籍设计对照](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md)维护。

[模块入口](../README.md)

带速捕获沿用书中2.2.1的磁链电压关系、现有[Flux库](../../../../lib/观测器/磁链/docs/公式推导.md)及[桥耦合物理库](../../../../lib/永磁同步电机/ref/README.md)。准备/拒绝流程为本工程组合设计，见[推导第10节](../docs/公式推导.md#10-flyingfluxfoc关断观察积分准备与带速接管)，不冒称复现书中某个带速算法。

| 资料 | 来源 |
|---|---|
| 书12.2.2电流模型MRAS | [MRAS库](../../../../lib/观测器/模型参考自适应/README.md)，原始书籍路径沿用本目录索引 |
| 书12.4的Kalman估计 | [EKF](../../../../lib/观测器/扩展卡尔曼/README.md)、[UKF](../../../../lib/观测器/无迹卡尔曼/README.md)，完整协方差和共享校正由lib维护 |
| 书12.3.3平滑滑模注入 | [sigmoid参数/源](../../../../lib/观测器/滑模/parameter/SIGMOID_PARAMETERS.md)，精确R-L部分与本拍注入保持 |
| 公共物理桥模板/辅助M | [sensorless_fw](../../sensorless_fw/README.md)，不把SPMSM观测器外推为凸极能力 |
| 工程符号 | [用户修订表](../../../../../docs/userdocs/符号定义表.md)，原文/单位不改 |
