# EEMF / 磁链 App 搭建记录

1. 以现有`SensorlessFOC.slx`为物理闭环模板，在独立目录创建`EemfSensorlessFOC.slx`和`FluxSensorlessFOC.slx`。模板不覆盖；保留Plant、Measurement、Controller、VoltageStage及其lib链接。
2. 保留Observer五入四出的边界，在内部重新搭建电压Clarke、50μs采样、与电流相同的反馈年龄、库观测器、诊断日志和五个Scope。使用`model_read → model_edit → model_read/model_check`记录连接；完整脚本为[build_observer_foc.m](build_observer_foc.m)。
3. EEMF链接`EmfObserver/EEMF`，七输入依次为uα、uβ、iα、iβ、direction、enable、reset。y1–y3给控制反馈，y8/y9的二范数给接管残差。库的UnitDelay把当前测量/电压用于下一状态，电机真实角度和速度不进入观测器。
4. Flux链接`FluxObserver/Flux`，六输入为uα、uβ、iα、iβ、enable、reset。y1–y3给反馈，y12给等效磁链幅值残差。direction在适配层记录并终止，不伪造估计电流。
5. 新参数函数复用共同配置，并分别提供`emfCfg`或`fluxCfg`。PostLoadFcn只调用相邻build_process中的初始化函数，运行器使用SimulationInput覆盖模型工作区；从模板带入的未用smoCfg被移除。
6. 首次EEMF仿真暴露会话中的`pi=2619`名称冲突，Settings错误解析为1.5714e6rad/s。保存残留值并清理名称冲突后，同一300Hz配置实际为1884.96rad/s，默认闭环通过。算法增益和外部验收阈值未因此修改。
7. 首次Flux接管沿用SMO的1.5A残差限，在约0.397s退出。Flux诊断是幅值误差/L，故改为本观测器已有的5A-equivalent资格，即默认5mWb，并与接管阈值同步；角度、速度、电流及融合电压跳变的外部验收标准保持原值。
8. 各运行八种工况，保存实际参数、输入、四组数据及指标。再从当前M源独立重建两份模型，默认40001点、四组日志与已验证默认结果逐值完全一致。正式目录还需通过对应的路径/链接/默认结果核对，见[验证记录](../waveform_analysis/observer_foc_verification.json)。

两者均为平均逆变器MIL：Observer使用最终作用相电压的理想采样值；占空比+实测母线重建、SIL、C2000目标时序和实机效果未由本轮证明。模型零电压请求也不等于功率级高阻断开；故障后实测约15.89A短路制动峰值已在波形分析中单独列出，不计为安全关断完成。

[运行方法](OBSERVER_USAGE.md) · [结果](../waveform_analysis/OBSERVER_ANALYSIS.md) · [模块入口](../README.md)
