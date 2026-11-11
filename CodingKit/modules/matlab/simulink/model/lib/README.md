# 可复用模型积木

本目录按功能保存可复用模型、参数与组件独立测试台。观测器统一在[观测器](观测器/README.md)维护。受保护模型及其接口、配置与验证见[发布契约](../../docs/interfaces/PROTECTED_MODELS.md)。完整算法装配存放在[app_models](../app_models/README.md)。

| 模块 | 内容 |
|---|---|
| [离散并联PID](离散并联PID/README.md) | 离散PID/PI |
| [math](math/README.md) | Clarke/Park正逆变换、同坐标电流参考混合BlendDQ |
| [永磁同步电机](永磁同步电机/README.md) | 线性PMSM及高频/饱和物理对象；新增14项MIL，支持凸极、极性脉冲和实际位移测试；另有桥耦合库/Test，15项模型与18组纯M检查区分关断、整流与短路 |
| [电流环](电流环/README.md) | 普通/坐标跟踪电流PI与电压限制；新PI 10项独立MIL、旧电流环6项回归 |
| [逆变器](逆变器/README.md) | SVPWM与平均逆变器 |
| [采样执行时序](采样执行时序/README.md) | 采样保持与执行延迟 |
| [运动环](运动环/README.md) | 速度PI、位置P、限幅及带复位的离散速度给定 |
| [电压前馈](电压前馈/README.md) | dq解耦与反电势前馈 |
| [死区补偿](死区补偿/README.md) | 死区误差与补偿 |
| [MTPA弱磁](MTPA弱磁/README.md) | MTPA、弱磁和统一分配 |
| [相位跟踪](相位跟踪/README.md) | R2026b相位PLL、独立/实例隔离测试台及15项MIL |
| [滑模](观测器/滑模/README.md) | 基础SMO原14项；新增sigmoid库/Test与22项MIL，10项纯M、实例隔离、6次匹配对照另计，保留10mA噪声资格限制 |
| [反电势](观测器/反电势/README.md) | SPMSM线性Luenberger与IPMSM扩展反电势，复用PLL，3个SLX及32项独立MIL |
| [高频注入](观测器/高频注入/README.md) | 轴线、实测张量资格、均值校准和双脉冲；3个SLX、57项轴线/探针MIL；启动App另有22项组合MIL |
| [扩展卡尔曼](观测器/扩展卡尔曼/README.md) | 四状态SPMSM、Joseph校正及角变化率资格；2个SLX/25项独立MIL，完整P、合成分支反例和并行实例另验 |
| [无迹卡尔曼](观测器/无迹卡尔曼/README.md) | 共用四状态/线性校正的9点UKF；2个SLX/29项独立MIL，21项纯M、实例隔离和25匹配对照另计 |
| [模型参考自适应](观测器/模型参考自适应/README.md) | SPMSM一步电流模型MRAS、归一化PI及连续资格；2个SLX、24项独立MIL，另有并行实例检查 |
| [磁链](观测器/磁链/README.md) | SPMSM泄漏积分、直流去除和离散频率补偿，2个SLX、24项独立MIL及初值/偏置/相位反例 |
| [无感启动](无感启动/README.md) | 对齐、I-f爬升、接管与超时，10项独立MIL |
| [无感切换](无感切换/README.md) | 持续资格、平滑包角混合、短时预测和失锁退出，19项独立MIL |

各模块的库和验证模型都放自己的src。库模型不带Test后缀，验证模型以Test结尾；同一lib可按功能保留多组。App通过库链接复用。组件测试可使用公共测试运行器；测试装配依赖不属于生产库算法依赖。

无位置传感器积木的主要书籍参考、章节与算法边界见[书籍设计核对](../../docs/references/BOOK_SENSORLESS_DESIGN.md)。

## 无位置传感器积木计划

可复用角度跟踪、SMO、EMF/EEMF、磁链、HFI、MRAS、EKF、UKF及启动/切换均在本目录维护。基础SMO与sigmoid两组库/Test同属observer_smo，App共用这些积木。

以上无位置观测、启动和融合10类库共26个SLX、301项独立MIL，包含拒绝/故障及噪声限制场景。HFI位置启动22、低速FOC24、双向融合18项物理App MIL另计；电流坐标PI、运动给定及Sensor并行对照也分别记录。UKF21项纯M/25匹配对照、sigmoid10项纯M/6次对照及各库实例隔离不重复算成新的正常运行点。顺序和剩余App/代码验证见[无位置传感器计划](../../docs/plans/SENSORLESS_PLAN.md)。

[返回model](../README.md)

MRAS/EKF/UKF/sigmoid的[实际SPMSM闭环App](../app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)已新增40项检查；这批App通过Library Link复用本目录算法，保留各自独立MIL数量与边界。
