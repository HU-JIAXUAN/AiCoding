# 无转子位置传感器的App

本目录保存无位置传感器完整算法；首个[sensorless_foc](sensorless_foc/README.md)已完成SPMSM闭环与8项MIL。Sensorless指不使用转子位置传感器参与控制；电流测量与电流重构方案在具体App中说明。

闭环 App 使用观测器的角度和速度，按实际方案实现启动与切换。I-f、V/f 独立开环 App 使用软件角度和频率。仿真对象真实角度可用于误差对照，不能代替估算量参与无位置传感器闭环。

通用PID、坐标变换、电机对象、电流环、逆变器、MTPA/FW等继续复用[lib](../../lib/README.md)。实现具体算法时，再按功能建立App目录，并保留README、src、parameter、build_process、waveform_analysis和ref。

lib与App组合按[主要书籍设计核对](../../../docs/references/BOOK_SENSORLESS_DESIGN.md)推进；HFI轴线、极性和高低速融合分步验证，当前FOC的理想执行电压基线与后续硬件重建支路分别记录。

## 建设计划

[无位置传感器计划](../../../docs/plans/SENSORLESS_PLAN.md)统一列出步骤和lib清单。观测器在lib维护，本目录只保存完整算法装配、工况和结果说明。

| App目录 | 内容 | 状态 |
|---|---|---|
| [sensorless_foc](sensorless_foc/README.md) | SMO/EEMF/Flux三份启动、磁链带速，以及MRAS/EKF/UKF/sigmoid四种物理FOC | 原24项＋带速13项＋扩展40项App MIL；带速8组纯M另计 |
| [sensorless_hfi](sensorless_hfi/README.md) | 凸极/均值校准、极性启动、HFI低速FOC及基波双向融合 | 启动22项、低速FOC24项、物理融合18项MIL |
| [sensorless_fw](sensorless_fw/README.md) | 凸极EEMF闭环、MTPA/弱磁与运行时母线 | 7项核心＋9项边界检查，含2项明确反例；29组Scope/六组日志 |
| [sensorless_if](sensorless_if/README.md) | 软件旋转电流矢量、虚拟 dq PI 与物理桥/SPMSM | 13 项 MIL，另做步长复核 |
| [sensorless_vf](sensorless_vf/README.md) | 软件角度和 V/f 电压给定、共用物理桥/SPMSM | 13 项 MIL，原 demo 保留在 ref |

先完成PLL、SMO并行估算、启动与切换；再建立首个无位置闭环。MRAS/EKF/UKF等扩展不作为首个闭环的前置条件。

[App分类](../README.md) · [Sensor](../Sensor/README.md)
