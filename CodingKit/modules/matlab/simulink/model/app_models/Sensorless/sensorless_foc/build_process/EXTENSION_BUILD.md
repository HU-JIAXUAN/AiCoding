# 四种扩展观测器的物理FOC装配

| 模型 | 复用观测库 | 配置选择 |
|---|---|---|
| MrasSensorlessFOC | MrasObserver/CurrentModelMRAS | mras |
| EkfSensorlessFOC | EkfObserver/EKF | ekf |
| UkfSensorlessFOC | UkfObserver/UKF，内部复用KalmanMeasurement | ukf |
| SigmoidSensorlessFOC | SigmoidSlidingModeObserver/SigmoidSMO | sigmoid |

1. `build_extension_foc`从已建SensorlessFieldWeakeningFOC另存新模型，拒绝覆盖已有App。模板保持字节不变；结构/参数/布局修改使用model_edit，每个作用域先读图、后核对连接。四份App都保留20个库链接。
2. `extension_foc_parameters`在本模块组合公共配置，使用Ld=Lq=1mH的SPMSM。电流/观测50μs，物理桥5μs，速度PI1ms，默认80机械rad/s。MTPA/FW关闭，分配器提供受限q参考；这四种现有观测实现不作为IPMSM替代品。
3. 原Controller、Measurement、VoltageStage、物理Plant不复制算法实现。替换Observer子系统，在其中插入对应已有库链接，统一接七个标量：uα/uβ/iα/iβ/direction/enable/reset。电压来自物理桥的实际端电压；电流来自实际采样，按原有数据年龄处理。
4. Observer对上层只导出估角、估速、valid、电流残差范数及启动观察用端电压模长。MRAS残差取y8/y9的dq一步模型误差；EKF/UKF取y6/y7电流创新；sigmoid取y8/y9电流估计误差。它们都用A作上层残差量，不把NIS或归一化MRAS误差当作A。
5. 内部日志保留所有库输出，方便分析各算法自身指标。MRAS为25列、EKF/UKF为49列、sigmoid为23列；完整协方差按列展开16列。其余五组日志与物理模板一致，具体列号由extension_foc_channels生成。
6. 重启互锁改用实际端电压αβ模长：50ms观察后≤0.25V才许可对齐。它不依赖估计速度在初值时是否为0。相关端口/块重命名为voltage_magnitude、StartVoltageLimit和ObservedVoltageScope；当前许可已锁存后，正常运行电压上升不撤销许可。失锁仍由Handover的1ms超时退出。
7. 新模型工作区在初始化时清空，再装入本App的参数M结构，避免模板emfCfg、deadtimeCfg等未使用字段残留。MRAS保留300电角rad/s正幅值初速先验，由direction给符号；EKF/UKF本App用0初始估速。真实物理初速和初始角仍由pmsmCfg控制，二者不连接到观测器。
8. 先做80ms编译/形状检查，再做2.2s默认物理接管。随后每种算法10项场景共40项，分别保留原始参数、输入、六组波形和指标；没有把独立lib测试数量并入App结果。
9. 对四个新App整理根图及第一层子系统，编译读取实际Scope宽度/来源。MRAS、sigmoid各30组；EKF、UKF各32组，共同24组的顺序逐模型核对相同。整理前后六组完整默认轨迹逐点差0。
10. 在另一个空src目录只复制本批14份M文件，重新调用构建器；复用的是已发布的物理模板和lib，而不是本批四个SLX。四份重建模型的六组默认数据均与已验证版本逐点相同。正式目录重放完成后由extension_verification.json登记。

本批源码依赖：工程路径初始化、既有lib，及[弱磁App](../../sensorless_fw/README.md)的物理模板、公共参数/日志定义与刺激/分析辅助函数。运行时的观测、控制和物理算法仍通过lib链接；配置和测试辅助的复用关系在M文件中明确，没有复制观测器实现。

[全部参数与Scope](../parameter/EXTENSION_PARAMETERS.md) · [运行](EXTENSION_USAGE.md) · [波形](../waveform_analysis/EXTENSION_ANALYSIS.md) · [本模块推导](../docs/公式推导.md)
