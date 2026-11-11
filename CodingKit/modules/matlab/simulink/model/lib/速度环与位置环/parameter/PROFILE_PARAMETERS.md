# SpeedProfile 配置、状态和 Scope

独立模型为`src/SpeedProfileTest.slx`，与原MotionLoopTest分开。调用实例通过Mask传入`profileCfg`，每个实例独立保存状态。

## 配置参数

默认入口为[speed_profile_parameters.m](speed_profile_parameters.m)，修改基础值后调用[refresh_speed_profile_parameters.m](refresh_speed_profile_parameters.m)。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e−6 | s | 每次更新的明确周期 |
| Minimum / Maximum | −15 / 15 | 机械rad/s | 给定边界，必须包含0 |
| RisingRate / FallingRate | 40 / 40 | 机械rad/s² | 上升、下降方向最大斜率，均用正值配置 |
| RisingStep / FallingStep | .002 / .002 | 机械rad/s/拍 | refresh计算Rate×Ts，不直接编辑 |

默认测试工况在[speed_profile_test_parameters.m](speed_profile_test_parameters.m)：Ts=50 μs，Duration=.5 s，初始请求0，.02 s请求10 rad/s，.2 s改为−10 rad/s，.28–.32 s禁能，.4 s复位一拍。输入表由[speed_profile_stimulus.m](../build_process/speed_profile_stimulus.m)生成；对应字段为ReferenceInitial、Reference、CommandTime、ReverseReference、ReverseTime、DisableStart、DisableEnd、ResetTime，时间单位s、参考单位rad/s。

## 输入信号

| 端口/输入表列 | 名称 | 单位/类型 | 来源及作用 |
|---|---|---|---|
| u1 / 1 | reference | 机械rad/s，double | 先夹入Minimum/Maximum，再限制每拍变化 |
| u2 / 2 | enable | 0/1，double兼容 | 低时输出及下一状态立即为0 |
| u3 / 3 | reset | 0/1，double兼容 | 高时优先清除输出和状态，不受enable影响 |

## 过程变量

| 名称 | 初值/单位 | 所在块及用途 |
|---|---|---|
| PreviousReference | 0，机械rad/s | UnitDelay保存上一拍已输出的给定，周期Ts |
| SpeedBounds | 机械rad/s | 对请求执行上下限 |
| RequestedStep / StepBounds | 机械rad/s/拍 | 请求减旧状态；夹在[−FallingStep,RisingStep] |
| NextReference | 机械rad/s | 旧状态加允许增量 |
| OutputAndNextState | 机械rad/s | 有效时给出NextReference，否则明确选0；同一路写回UnitDelay |
| StateDiagnostic | 机械rad/s | 观察本拍读取的旧状态；禁能/复位时显示0 |

重新使能时从已清零状态爬升，不按“上次执行到现在的时间差”计算大步长。禁能/复位到0本身不受斜率限制；调用方此时应已禁用控制，这个动作不是电机的受控减速轨迹。

## 输出信号

| 端口 | 名称 | 单位 | 用途 |
|---|---|---|---|
| y1 | limited | 机械rad/s | 本拍限幅、限斜率后的给定 |
| y2 | held_state | 机械rad/s | 本拍读取的旧状态诊断，inactive时0 |

ToWorkspace的`trace`共5列：reference、enable、reset、limited、held_state。全部按Ts记录，Structure With Time，不截断。

## Scope 通道

| Scope | 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 / trace列 |
|---|---|---|---|---|---|
| ReferenceScope | 1 | requested | Inputs.y1 | 机械rad/s，double | 原始请求 / 1 |
| ReferenceScope | 2 | limited | Profile.y1 | 机械rad/s，double | 当前输出 / 4 |
| ReferenceScope | 3 | held_state | Profile.y2 | 机械rad/s，double | 旧状态 / 5 |
| ControlScope | 1 | enable | Inputs.y2 | 0/1，double | 禁能区间 / 2 |
| ControlScope | 2 | reset | Inputs.y3 | 0/1，double | 复位优先 / 3 |
