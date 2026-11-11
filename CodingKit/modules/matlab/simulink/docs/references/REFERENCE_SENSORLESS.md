# 无位置传感器模型的参考来源

核对日期：2026-11-09。下面区分已读取的本地模型接口与用于推导的公开资料。各模块实际采用的方程、离散方法和适用电机写在本模块的build_process和parameter中；测试结果另存waveform_analysis。

## 主要书籍参考

《永磁同步电机无位置传感器控制》（诸自强、吴溪蒙，机械工业出版社）为本工程无位置传感器lib及App组合的主要理论参考。原文件：`F:\Study\Motor Control\网上相关资源\电机工程经典书系13册\永磁同步电机无位置传感器控制.pdf`。

已核对相关正文、方程和框图。[章节与实现对应表](BOOK_SENSORLESS_DESIGN.md)记录印刷页/PDF页、各lib采用内容、已有实现差异，以及HFI/极性/混合App的连接与验证项。书中实验结果不计入本工程MIL；UKF另用公开算法参考。

## 本地辅助demo

本次只读取ZIP目录和SLX内的XML，没有运行原工程，也没有修改或复制原始文件。

| 原始路径 | 主模型与观测器 | 已核对内容 |
|---|---|---|
| F:\Study\Motor Control\MBD\Simulink_demo\18.Lun_Model_Code.zip | BLDC_Lun.slx → Lunberger_Observer.slxp | 主模型通过Model Reference调用受保护观测器，外部4输入、2输出；内部观测方程未读取 |
| F:\Study\Motor Control\MBD\Simulink_demo\19.SMO_Model_Code.zip | BLDC_SMO.slx → SMO.slxp | 同样为受保护观测器，外部4输入、2输出；不能把主模型中的SVPWM MATLAB Function当作SMO实现 |
| F:\Study\Motor Control\MBD\Simulink_demo\20.EKF_Model_Code.zip | BLDC_EKF.slx → EKF.slxp | 同样为受保护观测器，外部4输入、2输出；尚未取得可读的状态预测和协方差更新实现 |
| F:\Study\Motor Control\MBD\Simulink_demo\23.Nonlinear flux observer.zip | UART.slx | 归档中的SLX为UART主模型；本次没有将其记为已读取的磁链观测器算法 |

这些demo用于了解独立观测器与整机连接的方式。本工程重新建立可读的通用库和独立测试，不依赖上述受保护模型。控制环、坐标变换与对象的chensha来源核对保留在[已有参考索引](REFERENCE_06_14.md)。

## 方程和算法资料

| 资料 | 本工程核对重点 |
|---|---|
| [MathWorks Sliding Mode Observer](https://www.mathworks.com/help/mcb/ref/slidingmodeobserver.html) | SPMSM电压/电流输入、滑模电流模型与相位估算 |
| [MathWorks Extended EMF Observer](https://www.mathworks.com/help/mcb/ref/extendedemfobserver.html) | Ld/Lq不同条件下的扩展反电势、J矩阵符号和电角速度定义 |
| [MathWorks Flux Observer](https://www.mathworks.com/help/mcb/ref/fluxobserver.html) | 电压模型积分、SPMSM磁链和直流偏置；泄漏积分会有频率误差，不能直接当纯积分 |
| [Shah、Espinosa-Perez、Ortega、Hilairet：Sensorless speed control of PMSM](https://publiweb.femto-st.fr/tntnet/entries/6083/documents/author/data) | 第1.6节SPMSM非线性磁链观测方程与磁链模长约束；成立条件单独核对 |
| [MathWorks Pulsating High Freq Observer](https://www.mathworks.com/help/mcb/ref/pulsatinghighfreqobserver.html) | 凸极轴角度与π歧义，极性识别作为单独阶段 |
| [MathWorks 初始位置与双脉冲示例](https://www.mathworks.com/help/mcb/gs/estimate-initial-rotor-position-using-pulsating-high-frequency-dual-pulse-injection.html) | 双脉冲需要磁饱和/非线性对象，不能仅用常参数Ld/Lq证明极性识别 |
| [MathWorks EKF/UKF算法](https://www.mathworks.com/help/control/ug/extended-and-unscented-kalman-filter-algorithms-for-online-state-estimation.html) | 当前时刻校正、下一时刻预测，Jacobian、sigma点与协方差的更新顺序 |
| [PMSM EKF/UKF状态估计论文](https://www.tandfonline.com/doi/full/10.1080/00051144.2024.2354643) | 静止αβ坐标下电流、电角速度和位置状态；本工程不直接移植论文扩展参数估计器 |

上述文献不是本工程的运行结果。正反转符号、SI单位、样本所属时间和算法有效性均由各模块自己的测试记录核对。

[建设计划](../plans/SENSORLESS_PLAN.md) · [文档入口](../README.md)
