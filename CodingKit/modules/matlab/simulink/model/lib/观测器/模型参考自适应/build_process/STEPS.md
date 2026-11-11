# 电流模型MRAS的搭建与状态更新

主要参考《永磁同步电机无位置传感器控制》12.2.2，印刷306–307/PDF335–336页，式12.1–12.7、图12.2。实现使用SPMSM单一电感L；凸极电机的Ld/Lq不能直接代入一个L后当作同一方法。

## 1. 先测量，再做一步电流预测

把当前采样电流和当前实际作用电压变换到估算角对应的dq坐标，存为历史。下一拍以历史实测电流为初值，按电流方程做一步Euler预测：

```text
idCM[k] = idMeasured[k−1] + Ts/L·(ud[k−1] − Rs·id[k−1] + omega·L·iq[k−1])
iqCM[k] = iqMeasured[k−1] + Ts/L·(uq[k−1] − Rs·iq[k−1] − omega·L·id[k−1] − omega·Flux)
residual[k] = measuredDQ[k] − predictedDQ[k]
```

这里的起点是上一拍测得电流。iCM仅为本次一步预测结果，不能把上一拍iCM递推成另外一套连续电流观测状态。u[k]对应[kTs,(k+1)Ts)施加的电压；输入电流和电压的时间年龄要配套。

## 2. 从电流误差调节角度和速度

书中给出`residual/KCM ≈ [sin(deltaTheta);1−cos(deltaTheta)]`，其中`KCM=Ts·omega·Flux/L`。方向和频率接近时，d分量是相位误差的近似量。本实现用上一估算速度构造分母，保留其方向符号，设置最小幅值，避免低速除零。

残差先经过一阶低通，再将归一化d分量限制在±1内送入PI。PI的输出是电角速度：比例项为Kp·error，积分项按Ts·Ki·error更新。输出按方向限制在MinBootstrapOmega…MaxOmega，积分加入Kaw回算并有幅值限制。用修正后的速度推进下一拍角度，再用atan2(sin(theta),cos(theta))包角。

低通、速度先验、分母下限、限幅、回算和资格判定均是本工程添加，不能当成书中原图的全部内容。自然频率参数用于设计PI；实际动态、噪声代价和失配误差由测试结果判断。

## 3. valid单独判断

同时检查估速幅值、重建反电势幅值、归一化d误差与q一致性，并持续QualificationTime后才给valid。q分量用于补充d正弦误差的歧义：零速缺少基波激励和错误π分支都不能只凭d分量接近零放行。重建幅值来自同一电流模型，不是额外电压传感器的测量。

direction为外部方向先验，±1有效，0表示尚未确定并清状态。此模块不自行识别未知方向，也不完成零速磁极位置识别；App需要配置启动/捕获策略。参数、数据和噪声变化仍可能影响资格，独立轨迹通过不表示所有电机和硬件条件均可可靠捕获。

## 4. 21个显式状态和复位

| 索引 | 状态 | 单位/用途 |
|---|---|---|
| 1 | theta | 当前估算电角rad |
| 2 / 3 | speed_integral / omega | PI积分速度与输出电角rad/s |
| 4–5 | previous_measured_idq | A，上一拍测量，预测的初值 |
| 6–7 | previous_udq | V，对应上一采样区间的电压 |
| 8 | history_available | 0/1，第一拍只建立历史 |
| 9–10 | filtered_residual_dq | A，残差低通状态 |
| 11–12 | qualification_count / previous_direction | 拍 / −1,0,+1 |
| 13–14 | last_predicted_idq | A，上一次一步预测结果 |
| 15–16 | last_raw_residual_dq | A，上一处理拍的测量减预测 |
| 17–18 | last_normalized_dq | 1，实际用过的归一化误差 |
| 19–21 | emf_magnitude / fault / denominator | V / 故障码 / A |

禁能或复位清状态；方向从未知变为已知或正常反向时，从配置初始角和带符号速度先验重新捕获。非有限电压/电流锁存故障1，无效控制/配置锁存故障2；通过禁能/复位清除。未知方向也清空捕获状态。输出角度/速度/valid只消费保持状态及控制命令；当前电压只参与下一状态，避免形成电压控制代数环。诊断量比当前角度落后一拍，读波形时按此对齐。

## 5. 库与测试台

[build_mras_observer.m](build_mras_observer.m)先创建Mask，再创建引用cfg.Ts的端口；内嵌[mras_step.m](../src/mras_step.m)和[mras_output.m](../src/mras_output.m)。库默认配置来自mras_parameters()；App实例可将Mask改为自己的结构体变量。

独立测试台只向库连接前七列输入；最后两列真实角/速度只连接误差、记录和Scope。输入由[mras_fixture.m](mras_fixture.m)的连续dq电压平衡产生，未调用MRAS函数造参考结果。它规定转速和dq电流，不包含机械起转、逆变器限压或电机闭环控制。

搭建脚本拒绝覆盖已有SLX；复现请用独立模块副本，保留M源码，移走副本的两个SLX后调用脚本。仅编辑算法M不会自动替换模型内嵌源码，需要重建；编辑parameter中的默认值后重新初始化即可。

## 6. 类型修正及主机代码核对

原`count=0`使局部计数器推断为double，single代码生成在资格分支赋single值时发生冲突。改为`count=cast(0,'like',state)`，使计数器随状态类型；控制公式、阈值与21状态顺序保持。SLX内嵌同一M源码，只改外部M不会自动同步SLX。

本次在独立副本解除库锁，更新`MrasObserver:27`，回读后恢复锁。`model_edit`对FunctionScript返回不支持，改用与现有搭建脚本相同的公开`MATLABFunctionConfiguration.FunctionScript`接口；内部连接/原生端口/位置检查通过。库根7输入/16输出供调用方接线，根检查仍报告23个未连接导出端子，前后相同；内部连接单独核对。

修正后原24项独立MIL与10项物理App重放的26列/六组App数据逐点差为0；再从正式M生成double/single MEX和double C库SIL。入口、实际工具链、评分及数据见[主机代码分析](../waveform_analysis/HOST_CODE_ANALYSIS.md)。
