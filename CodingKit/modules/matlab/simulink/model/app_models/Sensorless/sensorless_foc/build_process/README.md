# 搭建过程

已按对象、采样、观测、控制、执行五块组装。[build_sensorless_foc.m](build_sensorless_foc.m)记录块、连接、参数和保存步骤；已有源模型时拒绝覆盖，重建需使用独立工程副本。[initialize_sensorless_foc.m](initialize_sensorless_foc.m)加载本模块参数和六列工况，[run_sensorless_foc_case.m](run_sensorless_foc_case.m)用SimulationInput运行并返回实际配置与四组日志。

接管前外环使用r=T_est−T_request−(SpeedKi/SpeedKaw)*speed_error，默认SpeedKaw=1/SpeedTs，使下一积分贡献等于T_est−SpeedKp*speed_error；接管后恢复正常分配残差。T_est由估算转子角下的测量iq计算，不取Plant转矩。启动与闭环电流参考通过math/BlendDQ转换到同一坐标，CurrentControl/FrameTrackingPI负责额外坐标纠正时的状态转换。

按[主要书籍复核](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md)，本版SMO输入来自VoltageStage的理想最终作用相电压，经Clarke变换取得αβ电压。这是理想MIL基线；后续在现有Measurement/VoltageStage中增加最终占空比与测得母线电压的重建支路，再验证死区、压降和样本延迟。当前结果不记为该支路已完成。

完整搭建说明、两段对齐的处理、积分跟踪公式、50 μs日志同步及运行示例见[USAGE.md](USAGE.md)。结果及对齐反例见[ANALYSIS.md](../waveform_analysis/ANALYSIS.md)。

| 记录 | 内容 |
|---|---|
| [app_diagram.png](app_diagram.png) | 顶层五个子系统 |
| [controller_diagram.png](controller_diagram.png) | 启动、接管和控制链 |
| [observer_diagram.png](observer_diagram.png) | 实际电压、电流与SMO |

EEMF/Flux两份App的[搭建记录](OBSERVER_STEPS.md)、[运行与调参](OBSERVER_USAGE.md)和[构建脚本](build_observer_foc.m)已补齐；仅重建Observer，保留共同闭环。批量运行器隐藏加载所需模型并关闭本次加载的模型，不打开编辑器或Scope。

[模块入口](../README.md)

新增带速App：[搭建过程](FLYING_BUILD.md)、[运行/调参](FLYING_USAGE.md)、[构建器](build_flying_foc.m)、[初始化](initialize_flying_foc.m)和[单次运行](run_flying_foc_case.m)。它使用桥耦合对象，关断观察时PI跟踪端电压，再接通PWM；不复制观测器实现。

扩展物理FOC：[搭建](EXTENSION_BUILD.md)、[运行](EXTENSION_USAGE.md)、[构建](build_extension_foc.m)、[初始化](initialize_extension_foc.m)、[单次仿真](run_extension_foc_case.m)、[布局](tidy_extension_foc.m)、[原生核对](inspect_extension_foc.m)。四份根图和Observer图按算法前缀保存，原四App保持字节不变。
