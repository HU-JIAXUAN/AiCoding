# PMSMBridgePlant 搭建过程

1. 现有Average只将占空比映射成电压，零电压会形成短路制动。本对象将桥和线性电机电气状态耦合求解，作为pmsm_plant的第三组库/Test；原有四份SLX不覆盖。
2. 对照指定书籍印刷32页/PDF61页式(2.14)，构造静止坐标L(theta)和永磁磁链；采用隐式电气磁链平衡、显式机械更新。开路、12种非零平衡三相导通组合共同覆盖二极管状态。
3. 先运行纯M物理核对，再以model_edit创建库BridgeMotor：三输入、16输出，Settings常量、PhysicalState延迟和Step/Measure两个MATLAB Function块。Measure只读状态；Step推进下一状态，并记录区间电压和下一拍电流诊断。完整脚本为[build_pmsm_bridge_plant.m](build_pmsm_bridge_plant.m)。
4. cfg Mask先于cfg.Ts端口建立；源函数通过公开MATLABFunctionConfiguration嵌入。创建映射按完整行解析ref，避免torque误匹配load_torque。初期构建失败均发生在临时未保存模型，已关闭后重新构建。
5. 独立Test通过库链接调用BridgeMotor，五列工况输入、33列记录、七组Scope。cfg来自本地M函数，PostLoadFcn仅使用相邻目录的初始化函数。16输出的图标扩大到340×480，便于读取接口。
6. 15项模型验证通过：14项物理动态与1项明确错误模式拒绝；18组纯M检查另计，其中240个SPMSM点用独立中性点二分法核对，240个IPMSM点核对KCL/KVL/二极管互补条件与功率。默认12001×33记录的嵌入源执行与M调度回放一致。
7. 从当前M源在新目录重建库/Test；默认全33列及时间与原默认结果完全一致。正式路径与源文件核对见[验证记录](../waveform_analysis/bridge_verification.json)。

母线为可吸收回馈能量的理想刚性电压源，二极管是示例PWL且无漏电/反向恢复；不含PWM纹波、寄生电容、母线电容和非线性饱和。还没有把旧App的故障退出改成此门极状态，也尚未证明硬件安全关断。

[参数/Scope](../parameter/BRIDGE_PARAMETERS.md) · [运行](BRIDGE_USAGE.md) · [结果](../waveform_analysis/BRIDGE_ANALYSIS.md)
