# 组装、运行与调参

## 怎样连接

1. Plant复用PMSMPlant的电气和机械积分模型。其真实角度只完成物理dq与αβ换算和日志评估。测量链把三相电流以50 μs采样、按FeedbackTicks延迟，再做Clarke变换。
2. VoltageStage复用Sensor对照模型中已验证的执行组合，底层仍是inverter、timing、deadtime和math库链接。SMO输入来自最终实际三相电压的Clarke变换，经过与电流相同的反馈年龄处理。限幅前PI请求不能直接当作实际电压。
3. Controller复用SensorlessStartup和SensorlessHandover。启动软件角是定子电流场角；先两个方向对齐，再I-f爬升。估算连续满足速度、角度、残差和valid条件后进入平滑混合，完成后AUTO。Plant角度没有连接到Controller。
4. BlendDQ先把启动电流旋转到当前控制坐标，再与闭环电流混合。速度环使用Handover保持的估算速度；短时观测器失效期间保持速度，避免SMO禁能输出归零被误当成电机突然停转。
5. FrameTrackingPI处理接管过程的额外坐标纠正，VoltageStage的可实现电压残差返回PI。关闭run后电流参考和请求电压归零。

## 对齐为什么增加电压选择

首轮实际PMSM仿真发现，恒电流对齐在低阻尼对象上留下较大的反向摆动，随后I-f未能捕获。没有提高机械阻尼来掩盖这个问题。当前在Startup模式2、3选择`v_align=AlignmentVoltageGain*i_ref`，默认增益为Rs；转动产生的反电势可提供电气阻尼。模式4后恢复电流PI。

对齐时PI仍更新，残差使用`r=r_limit+v_align-v_PI-(Ki/Kaw).*error`，其中d/q增益分别计算，默认Kaw=1/Ts。于是下一积分状态跟踪可实现对齐电压减去比例项。切回PI时已有相应状态。VoltageAlignmentEnable=0的工况保留为失败反例，证明这项处理的作用。此对齐电压是本App的明确方案，不是启动库对所有电机的保证。

速度PI接管前使用估算转矩跟踪，公式见本目录README；闭环后改为实际分配残差。额外坐标变化为`wrap(theta_used[k]-theta_used[k-1]-omega_base[k-1]*Ts)`，不能把每拍正常电角度旋转全部作为积分状态纠正量。具体PI状态变换见[FrameTrackingPI](../../../../lib/电流环/build_process/FRAME_TRACKING.md)。

## 在Simulink中运行

在本工程根目录运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
open_system('SensorlessFOC');
initialize_sensorless_foc('SensorlessFOC');
out=sim('SensorlessFOC');
```

也可打开SLX后点击Run。默认StopTime使用`experimentCfg.Duration`，ode4固定步长使用`experimentCfg.Step`。参数存放在模型工作区，修改Base Workspace同名变量不会覆盖它们。

## 修改参数

长期默认值编辑本模块[parameter/sensorless_foc_parameters.m](../parameter/sensorless_foc_parameters.m)，然后执行`initialize_sensorless_foc('SensorlessFOC')`再运行。启动、接管、SMO与PLL默认值引用对应lib的参数函数，本App在同一入口覆盖Ts和电机实例。工况事件在[sensorless_foc_stimulus.m](../parameter/sensorless_foc_stimulus.m)中按整数采样点生成。

单次实验建议使用返回结构体，避免改写源模型：

```matlab
p=sensorless_foc_parameters();
p.focCfg.SpeedReference=60;
p.focCfg.LoadTorque=0.08;
p.inverterCfg.Vdc=36;
r=run_sensorless_foc_case(p);
plot(r.time,r.plant.trace(:,r.plant.columns.speed_true));
```

运行器会刷新母线限值、SMO及启动/接管派生系数并检查周期整除关系。当前基础SMO要求Ld=Lq；修改电机时必须保持该适用条件。改变Ts时还需同步所有离散配置并重新设计增益，不能只改求解器步长。

```matlab
addpath(fullfile(fileparts(which('SensorlessFOC')),'..','waveform_analysis'));
report=run_sensorless_foc_validation();
```

验证工况和阈值在[sensorless_foc_validation_parameters.m](../parameter/sensorless_foc_validation_parameters.m)。运行器支持如`run_sensorless_foc_validation({'positive','observer_loss'})`的子集；子集会重写结果文件，因此完整报告以随后一次全量运行为准。

## 读Scope和日志

Scope按角度、速度、电流、转矩、电压和状态分开，实际顺序见[参数页](../parameter/README.md)。保存日志为plant_trace 13列、observer_trace 20列、controller_trace 46列、actuation_trace 26列，统一50 μs。列映射来自[sensorless_foc_channels.m](../parameter/sensorless_foc_channels.m)，读取结果使用`r.<stage>.columns.<name>`，避免手填列号。

控制器日志混合了50 μs和1 ms信号。四个慢变量在日志分支经显式RateTransition转到50 μs，保持上一慢拍值；这不修改控制链，也不新增控制延迟。Integrity/Deterministic关闭仅用于当前单任务MIL日志，不作为C2000跨任务数据原子性证据。

## 失锁含义

资格丢失累计到1 ms后Handover故障锁存，run归零，复位或禁能后才可重新启动。当前平均逆变器的零电压命令代表零平均电压，不代表功率管高阻断开；故障后的机械/电流变化不能用来证明实机保护或自由续流行为。飞行捕获、任意反转重启、板上时序和PIL仍需后续实现及实测。
