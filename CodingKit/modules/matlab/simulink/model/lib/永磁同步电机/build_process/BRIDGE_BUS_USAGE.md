# 运行时母线桥模型运行方法

在MATLAB中将当前目录切到simulink工程根，先执行：

    addpath('docs/scripts');
    initialize_motor_paths();
    open_system('PMSMBridgeBusPlantTest');

模型加载回调执行[initialize_bridge_bus_test.m](initialize_bridge_bus_test.m)，从本模块parameter读取默认值并生成6列输入。点击Run即可运行60ms的48→24→48V示例。

修改默认值时，编辑[bridge_bus_test_parameters.m](../parameter/bridge_bus_test_parameters.m)，随后执行：

    clear bridge_bus_test_parameters
    initialize_bridge_bus_test('PMSMBridgeBusPlantTest');

再次点击Run。对已加载的模型，仅保存M文件不会替换已经存入模型工作区的旧参数。

单次实验可直接覆盖返回的结构体，不修改SLX：

    p=bridge_bus_test_parameters();
    p.bridgeTestCfg.BusTimes=[0,0.02,0.04];
    p.bridgeTestCfg.BusValues=[48,36,48];
    r=run_bridge_bus_case(p);
    plot(r.time,r.trace(:,r.columns.dc_current));
    xlabel('Time (s)'); ylabel('i_{dc} (A)'); grid on

将`ModeTimes=0`、`ModeValues=0`可全程全关断；`ModeValues=2`为主动短路。母线变化请改BusTimes/BusValues或第4端口，不要只改名义bridgeCfg.Vdc。事件时间必须落在Ts采样网格上。

九组Scope在Test根层。先看BusVoltageScope确认输入，再看PhaseVoltageScope/PhaseCurrentScope、BusCurrentScope和PowerScope。负的idc表示回馈；关断时有电流可能来自二极管。各通道顺序、单位、当前值与区间值的区别见[参数页](../parameter/BRIDGE_BUS_PARAMETERS.md)。

完整检查与重新绘图：

    run_bridge_bus_validation();
    export_bridge_bus_plots();

验证包含6项正常工况/数值检查和4项预期拒绝。原始MAT保存实际参数、6列输入、时间、34列trace和列名；结果见[分析](../waveform_analysis/BRIDGE_BUS_ANALYSIS.md)。运行器只关闭自己加载的模型；若调用前模型已加载，会保留加载状态。

该对象规定外部母线电压，能够吸收回馈，不仿真母线电容过压。零、负值、NaN和Inf会停止仿真。`MechanicalEnabled=0`表示外部维持速度，不能将该工况回馈能量解释成自由转子的动能减少。

[模型构建](BRIDGE_BUS_BUILD.md) · [模块入口](../README.md)
