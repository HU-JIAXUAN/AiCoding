# 启动模块搭建与作用

1. 创建SensorlessStartup库及Startup子系统，四个Inport经Mux形成输入向量，八个Outport由Demux展开输出。
2. Unit Delay保存[mode,stageSamples,theta,ifSamples,fault]，初值为[0,0,Theta0,0,0]。SequenceStep是无persistent状态的MATLAB Function，输入本拍状态、控制输入和配置，输出下一拍状态及本拍请求。状态在图上可直接定位。
3. 模式0为关闭；1保持零电流，留给上层检测带速状态；2把软件矢量设为-direction·π/2并缓慢增加对齐电流；3将矢量转到0并保持。先用两个方向定向，避免只向一个固定方向施流时恰好处于180°零转矩平衡。
4. 模式4逐步增加带符号电角速度，并把电流幅值从AlignCurrent增加到StartupCurrent；模式5保持端点等待捕获。虚拟d电流是电流矢量幅值，虚拟q为0；转子相对电流矢量的负载角产生转矩，不能把theta_start当成转子真值。
5. 爬升/等待时，theta[k+1]=wrap(theta[k]+Ts·omega[k])，对外输出theta[k]。时间转为round(time/Ts)个采样点，当前阶段elapsed=stageSamples·Ts；换阶段计数清零。
6. acquired由上层完成闭环接管后的标志提供，App中延迟一拍，进入模式6，启动电流请求归零。超时进入模式7/fault=1，非法方向为fault=2，非法内部模式为fault=3。首个故障锁存；acquired和方向变化都不能清除，enable=0或reset=1才复位。
7. 库Mask逐实例解析startupCfg。结构和连线经model_edit建立，函数源由公开MATLABFunctionConfiguration.FunctionScript导入；model_read回读，model_check检查连线。测试台从模块工作区取得配置和输入，不依赖base workspace。

两阶段对齐、时间与电流是本仿真夹具起点，不能据独立序列测试保证任意负载实际起转。后续App需核对真实电流、速度、转矩、同步负载角和捕获结果。
