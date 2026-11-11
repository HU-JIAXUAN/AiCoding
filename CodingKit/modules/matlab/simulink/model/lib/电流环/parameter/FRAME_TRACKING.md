# FrameTrackingPI：配置、信号与 Scope

本页只对应 [FrameTrackingPITest.slx](../src/FrameTrackingPITest.slx)。原 CurrentLoopTest 的通道继续见 [README](README.md)。向量元素顺序统一为 d、q。

## 配置参数

| 名称 | 默认值 | 单位 | 含义/定义文件 |
|---|---|---|---|
| currentCfg.Ts | 50e-6 | s | 新测试台周期；[frame_pi_test_parameters.m](frame_pi_test_parameters.m) 覆盖原参数100µs，不改变原测试默认值 |
| currentCfg.Kpd / Kpq | 3.1415927 / 3.7699112 | V/A | 不相等的两轴比例增益；引用 [current_parameters.m](current_parameters.m) |
| currentCfg.Kid / Kiq | 1570.7963 / 1570.7963 | V/(A·s) | 积分增益，源文件同上；纯坐标/比例/前馈试验覆盖为0 |
| currentCfg.Kaw | 1000 | 1/s | 最终电压残差回算增益；坐标试验与无回算对照覆盖为0 |
| inverterCfg.LinearLimit | 26.6043004 | V | [inverter_parameters.m](../../逆变器/parameter/inverter_parameters.m)，48V母线、2%占空比裕量；饱和案例覆盖2V |
| testCfg.UseInternalLimit | 0 | 逻辑兼容double | 0选择外部残差，1选择VoltageLimit输出减总请求；[frame_pi_test_parameters.m](frame_pi_test_parameters.m) |
| testCfg.StopTime | 0.06 | s | 仿真终止时间；定义文件同上 |

library Mask字段currentCfg在每个调用实例单独求值；测试台的默认配置在模型工作区，不依赖base workspace。所有测试参数快照保存于frame_pi_results.mat。

## 输入信号

| 名称 | 单位 | 类型 | 来源/计算或用途 |
|---|---|---|---|
| error_dq | A | double[2] | 电流给定减反馈，两轴必须在theta_used坐标中 |
| voltage_residual | V | double[2] | 最终可行电压减PI+前馈总请求，同拍、同坐标；仅影响下一拍状态 |
| feedforward_dq | V | double[2] | 当前真正加入总请求的前馈；测试台经过Active门控 |
| delta_extra | rad | double | 当前坐标变化扣除正常旋转后的额外修正，见 [计算说明](../build_process/FRAME_TRACKING.md) |
| track | 1 | double | >0.5执行坐标/前馈状态转换 |
| enable / reset | 1 | double | enable<0.5或reset>0.5时输出及下一状态清零 |

默认类型double，更新周期currentCfg.Ts。源码保留like-cast，但本页验证仅证明double，不计为single或代码验证。

测试FromWorkspace为testStim结构，time是整数采样索引乘Ts，Interpolate=off。10列输入：1 e_d(A)、2 e_q(A)、3 外部r_d(V)、4 外部r_q(V)、5 原始FF_d(V)、6 原始FF_q(V)、7 delta_extra(rad)、8 track、9 enable、10 reset。最后3项为逻辑兼容double。原始FF与实际加入的FF不同：inactive时后者为0。

## 过程变量

| 名称 | 单位/初值 | 来源/所在块 | 计算或用途 |
|---|---|---|---|
| state(1:2) | V / [0;0] | FramePI/state UnitDelay | 本拍读取的Iprev |
| state(3:4) | A / [0;0] | 同上 | 上一拍误差，区分坐标变化与新的物理误差 |
| state(5:6) | V / [0;0] | 同上 | 上一拍比例电压 |
| state(7:8) | V / [0;0] | 同上 | 上一拍实际前馈 |
| integral_base | V | Compute输出2 | 变换后的本拍积分基值，track低时等于Iprev |
| total_voltage | V | TotalVoltage | PI电压加实际FF，限制前请求 |
| internal_residual | V | InternalResidual | 限制输出减总请求 |
| active | 1 | enable AND NOT reset | 测试台FF门控与状态观察 |

## 输出信号

| 名称 | 单位 | 类型 | 来源/用途 |
|---|---|---|---|
| voltage_pi | V | double[2] | Compute输出1，积分基值加当前比例项，不包含FF |
| integral_base | V | double[2] | Compute输出2，含本拍坐标转换，未加本拍积分增量 |
| integral_state | V | double[2] | Compute输出4，变换前Iprev，inactive时门控0 |

## Scope 通道

下表序号均是各Scope内部顺序。每个Scope使用一个输入端口，Mux将下列向量按元素展开。ToWorkspace保存30×1×N；[验证脚本](../waveform_analysis/run_frame_pi_validation.m)转换为N×30的records.<case>.trace。表中的列号均指转换后的trace，时间为records.<case>.time。

| Scope | 序号 | 名称 | 来源 | 单位/记录类型 | trace列 / 观察内容 |
|---|---|---|---|---|---|
| ErrorScope | 1、2 | e_d、e_q | error Mux | A / double | 1、2；输入误差，不是测量电流 |
| VoltageScope | 1、2 | total_d、total_q | TotalVoltage | V / double | 19、20；含FF的总请求 |
| VoltageScope | 3、4 | limited_d、limited_q | VoltageLimit输出1 | V / double | 21、22；圆限制后的可行电压 |
| IntegralScope | 1、2 | base_d、base_q | FramePI输出2 | V / double | 13、14；本拍变换基值 |
| IntegralScope | 3、4 | state_d、state_q | FramePI输出3 | V / double | 15、16；读取旧积分，inactive为0 |
| ResidualScope | 1、2 | residual_d、residual_q | ResidualUsed | V / double | 23、24；当前选择的残差，可在inactive时仍有外部输入 |
| ReferenceScope | 1、2 | new_pi_d、new_pi_q | FramePI输出1 | V / double | 11、12；新PI输出 |
| ReferenceScope | 3、4 | old_pi_d、old_pi_q | ReferencePI输出1 | V / double | 25、26；无坐标转换时与旧PI逐点比较 |
| TransferScope | 1 | delta_extra | inputs输出7 | rad / double | 7；额外坐标变化 |
| TransferScope | 2 | track | inputs输出8 | 1 / double | 8；跟踪请求 |
| TransferScope | 3 | active | ActiveDouble | 1 / double | 30；实际使能状态 |

未送入Scope、但已记录的列：3/4外部残差，5/6原始FF，9/10 enable/reset，17/18实际加入FF(V)，27/28旧PI积分(V)，29圆限制scale(1)。它们不能当作上述Scope中的额外通道。原始输入1:10均随数据保存并与请求逐点一致。

[模块入口](../README.md)
