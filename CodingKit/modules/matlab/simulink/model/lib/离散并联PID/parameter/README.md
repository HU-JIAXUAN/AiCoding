# DiscretePID 参数与信号说明

本目录统一说明配置参数、输入、过程变量、输出和示波器通道。运行、调参和构造输入的操作见 [USAGE.md](../build_process/USAGE.md)，块连接与计算顺序见 [STEPS.md](../build_process/STEPS.md)。当前误差、控制命令和对象输出使用无量纲测试量，不是电机电流、电压或速度；时间及增益的单位见下表。

## 配置参数

默认工况的可执行入口为[pid_test_parameters.m](pid_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_discrete_pid_test('DiscretePIDTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

唯一默认值定义文件：[discrete_pid_parameters.m](discrete_pid_parameters.m)。当前为无量纲 double 测试参数。

| 字段 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Kp | 1.2 | 1 | 比例增益 |
| Ki | 8 | 1/s | 积分增益，未预乘 Ts |
| Kd | 0 | s | 微分增益，默认关闭微分，保留 PI 行为 |
| Tf | 0.01 | s | 微分一阶低通时间常数，取正值；官方参考 N=1/Tf |
| Ts | 0.001 | s | 控制与测试对象采样周期 |
| UMin | -1 | 1 | active 输出下限 |
| UMax | 1 | 1 | active 输出上限 |
| X0 | 0 | 1 | 初始、复位、禁能后的积分贡献 |
| Kaw | 20 | 1/s | 回算增益，0 表示关闭 |
| PlantTau | 0.08 | s | 一阶测试对象时间常数，不属于 PID 掩码 |
| ClosedLoop | 1 | 1 | 1：负反馈；0：command 直接作为误差，不属于 PID 掩码 |

每拍积分更新使用 Ts*Ki、Ts*Kaw。改变 Ts 时不应把 Ki 再乘一次 Ts。增大 Kaw 会改变离散积分反馈动态，应重新验证。

Kd 不预除 Ts。微分支路通过后向欧拉离散实现一阶滤波微分；Tf 减小会减弱滤波，放大快速误差变化的影响。Kd=0 时滤波器仍跟踪误差变化率，但输出贡献为零。默认值是 PI，验证脚本中的 Kd=0.02 s 用于检查微分功能。

直接打开测试模型时，加载回调读取默认文件。修改默认文件后，关闭并重新打开测试模型，或调用 initialize_discrete_pid_test('DiscretePIDTest') 刷新模型工作区。单次实验使用 SimulationInput 覆盖 pidCfg；验证脚本不会改写默认文件。

每组实验最终 cfg 与输入保存在 `results.mat`（运行验证后生成） 的 cases 中。接入电流环时，e 改为 A、u 改为 V，Kp/Ki/Kd 的单位与数值需要随之确定。

## 输入信号

以下信号均每 Ts 更新。配置参数决定计算方式，输入信号则可以每拍变化。

| 名称 | 所在位置/类型 | 单位 | 来源与含义 |
|---|---|---|---|
| command | 测试输入，double | 1 | Command 从 pidStim.command 逐行读取；ClosedLoop=1 时是对象输出给定，ClosedLoop=0 时直接作为误差输入 |
| e | Controller 第 1 输入，double | 1 | ControlError 计算 command−ClosedLoop*plant_y；正误差使比例项增加 |
| enable | Controller 第 2 输入，boolean | 1 | Enable 读取 pidStim.enable；默认全 true；false 时输出归零、积分与微分状态复位 |
| reset | Controller 第 3 输入，boolean | 1 | Reset 读取 pidStim.reset；默认全 false；true 时同步复位，优先于 enable |

默认输入由 [initialize_discrete_pid_test.m](../build_process/initialize_discrete_pid_test.m) 建立：0–0.1 s 的 command=0，0.1–1 s 为 2，1–3 s 为 0.2。参考 2 超出当前一阶对象配合 ±1 输出限制的可达稳态值，用于观察饱和恢复。pidStim 是每路带 time=[]、signals.values、signals.dimensions=1 的结构，每 Ts 读取一行；不是把第一列当时间的普通矩阵。

## 过程变量

过程变量由 Simulink 块计算，不是额外要填写的整定参数。未列入 Scope 表的量目前没有直接送到示波器。

| 变量 | 单位 | 实现位置 | 计算/初值/作用 |
|---|---|---|---|
| active | 1，boolean | Controller/Active、NotReset | enable && !reset，控制输出及状态选择 |
| p | 1 | OutputStage/Proportional | Kp*e，比例贡献 |
| x[k] | 1 | IntegralUpdate/IntegralState | Unit Delay 保存上一拍写入的积分贡献，初值 X0 |
| x_i | 1 | IntegralUpdate/EffectiveIntegral | active 时取 x[k]，否则取 X0；这是诊断输出，不一定等于 inactive 第一拍 Delay 内尚未更新的旧值 |
| Ki*e | 1/s | IntegralUpdate/IntegralGain | 积分输入变化率；尚未乘 Ts |
| e_prev | 1 | DerivativeFilter/PreviousError | Unit Delay，初值 0；每拍记录当前 e，包括禁能/复位期间 |
| delta_e | 1 | DerivativeFilter/ErrorIncrement | e−e_prev；不是已经除以 Ts 的导数 |
| a_D | 1 | DerivativeMemoryGain | Tf/(Tf+Ts)，默认 10/11 |
| b_D | 1/s | DerivativeInputGain | 1/(Tf+Ts)，默认约 90.9091 1/s |
| s_prev | 1/s | DerivativeFilter/PreviousSlope | 上一拍的滤波斜率，初值 0 |
| s_D | 1/s | FilteredSlope、DerivativeReset | active 时 a_D*s_prev+b_D*delta_e，否则为 0；随后存为下一拍 s_prev |
| x_d | 1 | DerivativeFilter/DerivativeGain | Kd*s_D，微分对输出的贡献；Kd=0 时为 0 |
| v | 1 | OutputStage/UnsaturatedCommand | p+x_i+x_d，内部未限幅请求 |
| u_lim | 1 | OutputStage/OutputLimits | clamp(v,UMin,UMax)，内部限幅结果 |
| r_sat | 1 | OutputStage/SaturationError | u_lim−v；上饱和时为负，下饱和时为正 |
| Kaw*r_sat | 1/s | IntegralUpdate/BackCalculation | 把实际限幅差送回积分变化率；不直接对积分值做上下限裁剪 |
| delta_x | 1 | IntegralUpdate/SamplePeriod | Ts*(Ki*e+Kaw*r_sat)，每拍积分增量 |
| x_next | 1 | NextIntegralCandidate、StateReset | active 时 x_i+delta_x，否则为 X0；送入 Unit Delay，下一拍才成为其输出 |
| a_P / b_P | 1 | 测试模型 PlantMemory / PlantInput | exp(−Ts/PlantTau) 与 1−a_P，属于测试对象 |
| plant_y | 1 | 测试模型 PlantState | 对象输出，初值 0；y[k+1]=a_P*y[k]+b_P*u[k] |

## 输出信号

| 端口 | 名称 | 类型/单位 | 含义 |
|---|---|---|---|
| 1 | u | double / 1 | active 时的受限控制命令；inactive 强制为 0 |
| 2 | u_unsat | double / 1 | active 时为 v；inactive 强制为 0，不代表内部 v 永远为零 |
| 3 | saturated | boolean / 1 | active && (u_lim != v)；恰好等于边界但未被裁剪时可以是 false |
| 4 | x_i | double / 1 | 当前可见积分贡献；inactive 为 X0 |
| 5 | x_d | double / 1 | 当前微分贡献；inactive 或 Kd=0 时为 0 |

## Scope 通道

测试模型的 Waveforms 只有一个输入端口。TraceChannels 将以下九路按顺序合成向量，Scope 显示的是这个向量的第 1–9 个元素；顺序不按颜色推断。

| 通道/数据列 | 名称 | 来源 | 单位/记录类型 | 观察什么 |
|---|---|---|---|---|
| 1 | command | Command | 1 / double | 给定或直接误差；默认在 0.1 s 升到 2、1 s 降到 0.2 |
| 2 | error | ControlError | 1 / double | 控制器实际收到的 e；闭环下与 command 不同 |
| 3 | u | PIDUnderTest 输出 1 | 1 / double | 最终控制命令、限幅和停机归零 |
| 4 | u_unsat | PIDUnderTest 输出 2 | 1 / double | 限幅前请求；与通道 3 的差对应 active 时的限幅残差 |
| 5 | x_i | PIDUnderTest 输出 4 | 1 / double | 积分积累、回算及复位；它可以超出 UMin/UMax，受限的是 u |
| 6 | plant_y | PlantState | 1 / double | 测试对象响应；与通道 1 比较跟踪与恢复，当前不是电机速度或电流 |
| 7 | saturated | PIDUnderTest 输出 3，经 LimitFlagToDouble | 1 / double，0 或 1 | 原始端口为 boolean；1 表示本拍发生裁剪；禁能/复位时为 0 |
| 8 | official_reference | OfficialPIDReference | 1 / double | 同一误差的官方 PI/PID 输出；只在全程使能、无复位的对照工况评价差异 |
| 9 | x_d | PIDUnderTest 输出 5 | 1 / double | 微分贡献；默认 Kd=0，整条曲线应为零；Kd>0 的阶跃工况出现短暂峰值 |

Scope 没有直接记录 enable、reset、p、r_sat 或 s_D。enable/reset 可从 pidStim 的对应 signals.values 查看；批量结果中在 cases.<工况>.stim.enable/reset.Data。p 可用 Kp*error 算出；active 时 r_sat=通道3−通道4，s_D 与 x_d 的单位不同。

Scope 的九通道与 To Workspace 的九列完全同序：单次仿真为 out.pidTrace.signals.values(:,1:9)，批量数据为 cases.<工况>.trace.values(:,1:9)，时间分别在 out.pidTrace.time 与 trace.time；批量数据另有 trace.channels 保存列名。

### Scope 显示设置

| 设置 | 保存模型中核对的值 | 含义与操作 |
|---|---|---|
| NumInputPorts | 1 | 一路九元素向量，不是九路独立 Scope 端口 |
| SampleTime | -1 | 继承输入的 Ts，当前为 1 ms |
| LayoutDimensions | 1×1 | 九条曲线画在同一坐标区 |
| TimeSpan | Auto | Scope 自动选择显示时间窗口；横轴仿真时间单位为 s |
| AxesScaling / YLimits | Manual / [-1.2,2.8] | 默认工况可看；改变增益或关闭回算后，点击 Autoscale（自动缩放）查看超出原纵轴范围的积分等曲线 |
| ShowLegend | false | 在 Scope 工具栏/设置中启用 Legend（图例），再按上述序号识别、选择曲线；图例通用名称以实际界面为准 |
| DataLogging | false | Scope 自身未向 ScopeData 变量记录数据；本模型由旁路的 SaveTrace 块记录 pidTrace |

建议分组观察：跟踪用 1/6；限幅用 3/4/7；积分用 3/5；微分用 2/9；官方对照用 3/8。批量验证运行多次后，Scope 反映最后一次仿真；全部工况应查看 [五组波形及原始数据](../waveform_analysis/README.md)。

[返回模块](../README.md)

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |

### 本模块局部量

本独立测试使用无量纲误差e及输出u；Kp、Ki、Kd的单位分别为1、1/s、s，实际接入电流或速度环时还需乘输出/误差的量纲比。它们为通用控制局部参数，不把e解释为电机反电势。
