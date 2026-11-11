# HFI启动链搭建过程

1. 引用`HighFrequencyObserver/SaliencyProbe`、`HFIAxis`、`PolarityPulse`，以及共用物理PMSM和Clarke变换。App只组装库链接，算法状态和更新公式仍由lib维护。
2. 在Enabled Subsystem中执行正交凸极探针。探针的实际电压和电流回归二维逆电感，16元素输出经一拍快照交给后级；完成标志通过保持状态关闭该子系统，停止重复回归。禁能或复位重新运行探针以清除旧结果；快照更新同样经过一拍交接。
3. 将快照中的`qualified`用于启动准入，将`inverse_average`接入HFIAxis的第8输入，并启用`UseMeasuredInverseAverage`。测试名义Ld/Lq不准确时，连续解调仍使用测得均值；交叉电感引起的方向偏置仍需独立先验或标定。
4. HFIAxis复用双角PLL，先跟踪轴线和速度。PolarityPulse等待轴线连续有效且滤波速度足够低，随后冻结轴向并关闭HFI请求。该轴线仍存在π歧义，不能先作为完整磁极角使用。
5. 等电流衰减后施加正脉冲，等待衰减，再施加负脉冲。比较基线修正电流峰值；先检查实际伏秒相等、横向电压、最低剂量和峰值裕量，再形成π分支结论。实际u[k−1]与i[k]配对，执行延迟的末拍不能漏算。
6. 重新开启HFI，待轴线再次锁定后才输出`position_valid`。完整角度为`wrap(theta_axis+π·flip_pi)`。电压请求及阶段输出只依赖保持状态和凸极资格，完整角度/valid在独立块计算，避免同拍HFI资格反馈成代数环。全局enable/reset门控合成请求，清除快照交接期间的残余请求；故障锁存后停止平均电压请求。0 V平均模型不是实际逆变器高阻关断模型。
7. 实际PMSM包含增量凸极、磁极偏置饱和和正常惯量/阻尼，电流经三相ADC与Clarke回到估算链。真实θ/ω只进入误差与Scope，不参与上述判定。
8. 用独立`SimulationInput`工况检查正常极性、π翻转、ADC、时序、不凸极、无饱和、不等伏秒、运动、禁能/复位和故障。模型结构由[build_hfi_startup.m](build_hfi_startup.m)构建，物理MIL由[验证脚本](../waveform_analysis/run_hfi_startup_validation.m)执行。

本页及SensorlessHFIStartup保持独立位置启动链。转矩/速度闭环现已在同模块SensorlessHFIFOC组装，见[FOC搭建](FOC_BUILD.md)，不复制lib算法；HFI↔基波双向融合继续实施。
