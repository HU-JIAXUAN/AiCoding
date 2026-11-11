# 极性块搭建及校准接口扩展

[build_hfi_calibration.m](build_hfi_calibration.m)在原HFIAxis中追加第8输入`inverse_average_external`及第15输出`inverse_average_used`。解调仍按两个已执行电压区间和三个电流样本计算；仅各向同性分量的去除值可切换。名义模式保持原公式，实测模式拒绝非有限或非正的外部值。独立测试台前37列不动，新增第38列和CalibrationScope。

[build_hfi_polarity.m](build_hfi_polarity.m)向同一库追加`PolarityPulse`：

1. 十个Inport与十六个Outport组成公开接口，Mask参数`cfg`引用调用者的`polarityCfg`。
2. `PolarityStates`是19元素、Ts周期的UnitDelay；[hfi_polarity_update.m](../src/hfi_polarity_update.m)仅更新下一状态，禁能/reset清零。所有时长、峰值和剂量门限来自本模块M参数文件。
3. [hfi_polarity_output.m](../src/hfi_polarity_output.m)根据保持状态和凸极资格产生脉冲、HFI比例及状态诊断。内部第4/5元素是π偏置和READY，而非直接公开的完整角度/资格。
4. 将轴角与π偏置相加，再用sin/cos/atan2包角；将READY与axis_valid相与后转成double。公开y4/y5由这些独立块输出。这样脉冲和阶段输出不直接依赖同拍HFI锁定结果，避免MATLAB Function单一向量输出造成反馈代数环。
5. 实际电压在状态中保存一拍，下一拍与电流配对；正脉冲和其衰减阶段累计正剂量，负脉冲和其衰减阶段累计负剂量，包含执行延迟造成的末拍。
6. 轴线、速度、静息电流、峰值差、两侧实际剂量及横向电压共同约束识别；故障锁存直到禁能/复位。不以真实角度检验在线资格。

库块本身没有Scope。物理验证和运行位于[SensorlessHFIStartup](../../../../app_models/Sensorless/sensorless_hfi/README.md)，其中库链接不复制这些算法。完整输入/状态/输出及默认值见[POLARITY_PARAMETERS](../parameter/POLARITY_PARAMETERS.md)。

构建脚本要求R2026b；结构编辑使用model_edit，每个范围先读、编辑后再读并检查。库局部Mask在引用cfg.Ts前建立；检查内部后恢复完整Mask参数，再保存并关闭，切换到测试模型时不叠开库窗口。
