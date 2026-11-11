# 启动参数、状态与Scope

## 配置参数

默认工况的可执行入口为[startup_test_parameters.m](startup_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_startup_test('SensorlessStartupTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

默认定义为[startup_parameters.m](startup_parameters.m)，派生量由[refresh_startup_parameters.m](refresh_startup_parameters.m)更新。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts / Theta0 | 50e-6 / 0 | s / 电角rad | 周期与复位软件角度 |
| AlignCurrent / StartupCurrent | 2 / 3 | A | 对齐和I-f矢量幅值请求 |
| FinalOmega / MinCaptureOmega | 250 / 150 | 电角rad/s | 速度端点与允许捕获检查的下限 |
| FlyingCaptureTime | 0.03 | s | 零电流带速捕获窗口 |
| PrealignTime / PrealignRampTime | 0.06 / 0.03 | s | 首次定向总时长与电流爬升时间 |
| AlignTime / AlignRampTime | 0.08 / 0.04 | s | 第二次定向总时长与场角转动时间 |
| OmegaRampTime / CurrentRampTime | 0.35 / 0.05 | s | I-f速度和电流爬升时间 |
| MaxIFTime | 0.8 | s | I-f爬升加等待的总超时 |
| Samples | round(上述时间/Ts) | 采样点 | 依次为带速、首次对齐、首次电流爬升、二次对齐、场角转动、速度爬升、电流爬升、I-f超时 |
| Vector | 14×1 | 各字段单位 | Ts、Theta0、AlignCurrent、StartupCurrent、FinalOmega、Samples八项、MinCaptureOmega；Constant送入函数 |
| State0 | [0;0;Theta0;0;0] | 混合状态 | Unit Delay初值 |

Mask的Startup configuration为每实例配置表达式，默认startupCfg。修改时间/周期后必须刷新Samples和Vector，不能只改结构中的显示字段。

## 输入信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| enable | 0/1 | double / 1 | 总使能，0立即复位 |
| reset | 0/1 | double / 0 | 优先于全部动作 |
| direction | +1/-1 | double / +1 | 软件场旋转方向，0等非法值故障 |
| acquired | 0/1 | double / 0 | 上层AUTO标志，App中延迟一拍；只在全部接管后置1 |

testStim四列依次与上述四个输入相同。所有运行输入要求有限。

## 过程变量

| 名称 | 单位/初值 | 所在块 | 计算或用途 |
|---|---|---|---|
| state(1) mode | 0 | state Unit Delay | 0关闭、1带速窗口、2首次定向、3二次定向、4I-f爬升、5等待、6已接管、7故障 |
| state(2) stageSamples | 采样点 / 0 | 同上 | 当前阶段计数 |
| state(3) theta | rad / Theta0 | 同上 | 当前软件电流矢量角度 |
| state(4) ifSamples | 采样点 / 0 | 同上 | 模式4/5累计时长 |
| state(5) fault | 状态码 / 0 | 同上 | 1超时、2非法方向、3非法内部状态；故障锁存 |
| nextState | 与state相同 | SequenceStep输出1 | 下一采样点写入Unit Delay |

## 输出信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| theta_start | 电角rad，[-π,π] | double / Theta0 | SequenceStep输出向量1；软件场方向 |
| omega_start | 电角rad/s | double / 0 | 输出向量2；定向旋转或I-f速度请求 |
| id_start / iq_start | A | double / 0 | 输出向量3/4；软件场坐标中d为幅值、q为0 |
| ready | 0/1 | double / 0 | 向量5；模式4/5且速度达到MinCaptureOmega |
| mode / fault | 状态码 | double / 0 | 向量6/7；非真实电机启动成功标志 |
| elapsed | s | double / 0 | 向量8；stageSamples×Ts |

## Scope 通道

五个Scope均有一个输入端口。下面序号为端口向量内的通道顺序；trace为To Workspace记录，不与端口号混淆。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1 | theta_start | Startup输出1；trace5 | rad / double | 软件电流矢量角度及包角 |
| SpeedScope 1 | omega_start | Startup输出2；trace6 | rad/s / double | 定向转动和I-f爬升 |
| CurrentScope 1 | id_start | Startup输出3；trace7 | A / double | 对齐/I-f电流幅值请求 |
| CurrentScope 2 | iq_start | Startup输出4；trace8 | A / double | 本定义固定0 |
| StatusScope 1 | enable | inputs输出1；trace1 | 0/1 / double | 使能 |
| StatusScope 2 | reset | inputs输出2；trace2 | 0/1 / double | 复位 |
| StatusScope 3 | direction | inputs输出3；trace3 | ±1 / double | 指令方向 |
| StatusScope 4 | acquired | inputs输出4；trace4 | 0/1 / double | 上层已接管 |
| StatusScope 5 | ready | Startup输出5；trace9 | 0/1 / double | 允许捕获检查 |
| StatusScope 6 | mode | Startup输出6；trace10 | 状态码 / double | 当前序列阶段 |
| StatusScope 7 | fault | Startup输出7；trace11 | 原因码 / double | 锁存故障 |
| ElapsedScope 1 | elapsed | Startup输出8；trace12 | s / double | 阶段计时 |

状态码最高7，自动纵轴可能使0/1信号显得很小，可用Scope信号选择器单独看ready/fault。这里没有电流测量波形；CurrentScope记录的是请求，真实电流和电磁转矩在App中验证。

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |

### 本模块局部量

$\theta_s,\omega_s$为软件启动场角及其变化率，Theta0/FinalOmega不表示测得的转子初始角或速度。真实转子角速使用$\theta_r,\omega_r$；本模块自身不测量它们。

## I-f / V/f 命令组

[OpenLoopDrive 参数与端口](OPEN_LOOP_PARAMETERS.md)保存本组配置向量、状态顺序、14 列输出及五组 Scope。原 SensorlessStartup 的参数、接口和测试不变。
