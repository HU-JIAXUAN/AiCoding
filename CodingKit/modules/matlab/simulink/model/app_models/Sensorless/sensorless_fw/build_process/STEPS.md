# 从EEMF基线组装弱磁App

1. 使用`build_sensorless_fw`从现有EemfSensorlessFOC另存新App，检查模板未打开、未修改；不覆盖旧SLX。调用标准块与已有库，结构修改均由model_edit完成。
2. 在本模块参数入口恢复凸极电机：Ld=1mH、Lq=1.2mH，EEMF采用同一Rs/Ld/Lq/磁链。当前是合成验证电机，不是P650或自制板电机辨识结果。
3. 将Plant换为PMSMBridgeBusPlant/BridgeBusMotor库实例。它接收占空比、桥模式、外负载和真实母线；电流、转速、角度由物理状态推进。真实电角度仅用于Plant内计算真实dq电流，以及终止块；不会进入控制角度。
4. 保留实际相电流的Clarke/采样与EEMF/PLL。观测器输入使用物理对象端电压，包含执行延迟，不能使用限幅前PI请求代替。EEMF幅值额外导出给StartInterlock。
5. 删除原标量转矩到iq链，换CurrentReference/Allocator库链接。速度PI给转矩，分配器用估算电角速度、真实母线、上一完整电流拍的请求模长，输出id/iq与可分配转矩；回算转矩接回速度PI。估算电磁转矩包含凸极项。
6. VoltageStage先除真实母线，再复用电压圆限幅和SVPWM；库实例在局部mask中使用Vdc=1配置。恢复电压后形成同一命令时刻的可实现dq电压和抗饱和残差。PWMUpdate再施加一拍延迟，Plant实际端电压另外送EEMF。
7. 加StartInterlock：请求/复位/方向变化控制许可；观测器运行满50ms且EMF≤0.25V后才置许可。旋转中复位或重新使能先关断，再观察；不清空物理电流/转速状态。许可已锁存后，普通观测失效由Handover的1ms超时关断，不用瞬时valid直接切门极。
8. 原Startup→Handover→FrameTrackingPI链继续负责对齐、I-f、资格和坐标跟踪。当前App不启用FlyingCapture；方向切换需要先滑行到重新满足启动资格。关断仍由物理桥处理二极管续流/整流。
9. 四个boolean分配标志分别转换为double后才接日志Mux。增加分配、实际母线、关断、互锁Scopes，原生编译核实实际为29组。六组日志按不同物理/控制周期记录。
10. 按新模型层级运行布局引擎，model_read/model_check检查连接；布局前后六组完整轨迹逐点差0。再做7项核心、9项边界及纯M重建/正式路径重放。

初次接入时有两类记录：分配标志boolean与double混接造成编译错误；首次互锁配置中工具未接受UnitDelay的显式OutDataTypeStr，修正为从boolean输入继承类型，并在继续连接前读图/检查。上述问题均已修正；源构建脚本包含修正，不依赖手工补线。

[运行](USAGE.md) · [公式](../docs/公式推导.md) · [参数](../parameter/README.md)
