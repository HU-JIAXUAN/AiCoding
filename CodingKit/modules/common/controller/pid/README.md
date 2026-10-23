# PID 控制器模板

这是一个纯 C99、默认 `float` 的通用 PID 控制单元。它不是裸 PID 公式，而是把 PID 调节、目标整形、微分滤波、输出保护和积分抗饱和集中在一个 `pid(&controller)` 单入口里。控制器对象自己保存配置、输入、状态和输出；外部每个控制周期只写入输入字段，然后调用一次 `pid(&controller)`。

本模板源码已去耦、去敏：不依赖第三方项目，不在 C 源码中保留第三方项目名或上层业务语义。

## v1.6 变更

- 明确 `antiwindup_complete.slx` 的积分抗饱和拓扑。
- 确认当前 C 实现采用同一类 back-calculation 结构：
  `I(k+1) = I(k) + Ki * [e(k) + Kaw * (u_sat(k) - u_raw(k))] * Ts`。
- 新增 Simulink 参考模型拓扑检查，验证 `uc -> Saturation -> u` 与 `uc-u -> Kaw -> 积分输入` 的连接关系。
- 不改 `pid()` 外部接口，不改 PID 主算法，只补充等价依据和验证项。
- `src/*.c`、`src/*.h` 和 `examples/*.c` 继续使用 GBK 编码。

## 单位约定

PID 内核不绑定位置、速度、电流或其他上层业务，因此只约定三类单位：

| 类别 | 含义 | 标幺写法 |
|---|---|---|
| 被控量单位 | `setpoint`、`feedback`、`error` 使用的单位 | `pu` |
| 输出单位 | `output`、`feedforward`、P/I/D 分量使用的单位 | `pu` |
| 时间单位 | 频率用 Hz，内部周期用 s | 不适用 |

增益单位由输入/输出关系决定：

```text
kp: 输出单位 / 被控量单位
ki: 输出单位 / (被控量单位 * s)
kd: 输出单位 * s / 被控量单位
antiWindupGain: 被控量单位 / 输出单位
```

如果你的控制链路全部使用标幺，`setpoint`、`feedback`、`outputLimit`、`integralLimit` 等都按同一套标幺基准填写，并在上层换算到实际物理量。

## 为什么用控制频率

离散 PID 内部计算积分和微分时必须使用控制周期 `Ts`：

```text
I += Ki * error * Ts
D = (error - lastError) / Ts
```

但是用户在嵌入式工程里通常更容易知道定时器或中断频率，例如 `1 kHz`、`10 kHz`、`20 kHz`。所以本模板对外配置 `controlFreq`，内部换算：

```text
Ts = 1 / controlFreq
```

这样对用户更直观，也能减少控制周期小数写错的概率。若强实时路径特别在意除法开销，可以在上层固定频率并让编译器优化；当前模板优先保持配置简单。

## 编码约定

- `src/*.c`、`src/*.h` 和 `examples/*.c` 使用 **GBK** 编码。
- Markdown、Python、MATLAB/Simulink 脚本仍使用 UTF-8。
- 不允许同一个 C 源码包内混用 UTF-8 与 GBK。
- 后续 Agent 修改 C 文件时，应按 GBK 读取和写回，避免自动转成 UTF-8。

## 控制链说明

`pid(&controller)` 单周期执行顺序：

```text
1. 检查 controlFreq 和限幅配置
2. 对 setpoint 做限幅
3. 对 setpoint 做变化率限制
4. 对 feedback 做可选限幅
5. 计算 error = setpoint - feedback
6. 对 error 做可选限幅
7. 计算 P 项、I 项、D 项和 feedforward
8. 对 D 项微分做一阶低通滤波
9. 对求和后的原始 output 做 deadband
10. 对 output 做限幅
11. 根据 output 饱和情况执行 back-calculation 抗积分饱和
12. 更新 state 观测量
```

这些步骤不绑定任何上层业务。`setpoint` 可以来自任意控制对象，`output` 也可以交给任意执行层处理。

## 轻量先积分 PI

需要“先积分、后输出”的电流环时，可单独使用 [pid_pi.h](src/pid_pi.h)，无需创建通用 `Pid` 对象。`PidPi` 只保存 `kp`、`ki` 和积分，使用物理周期 `periodS`；这是一套独立接口，不改变下文通用 PID 的离散顺序与抗饱和行为。

1. `pid_pi_eval()` 计算 `I_next = clamp(I + Ki*Ts*error, ±limit)`，再计算 `u = clamp(Kp*error + I_next, ±limit)`，暂不修改 PI。
2. 调用方对多轴输出统一限幅后，将各轴最终指令交给 `pid_pi_track()`。指令变化时提交 `clamp(u_applied - Kp*error, ±limit)`，否则提交本拍积分候选。

`ki=0` 时积分始终为零。两个函数检查非有限数与限幅，失败不修改目标对象；同一实例由一个执行者独占，每个候选只提交一次。该小接口不包含滤波、斜率、设备或启停状态，原 `pid()`、`pid_eval()`、`pid_track()`、`Pid` 布局及固定参考均保持兼容。新增源码与原 `src/` 一样使用 GBK、LF。

## 内置控制工具边界

当前模块包含这些可选控制工具：

| 工具 | 字段/逻辑 | 默认效果 | 作用 |
|---|---|---|---|
| 目标限幅 | `setpointLimit` | 关闭 | 限制目标绝对范围 |
| 目标斜率限制 | `setpointRateEnable / setpointRate` | 关闭 | 限制目标每秒最大变化量 |
| 反馈限幅 | `feedbackLimit` | 关闭 | 裁剪异常反馈输入 |
| 误差限幅 | `errorLimit` | 关闭 | 限制误差参与 P/I/D 的范围 |
| 微分滤波 | `derivativeFilterCoef` | 0 时不滤波 | 降低 D 项对噪声的敏感度 |
| 积分限幅 | `integralLimit` | 关闭 | 限制 I 分量大小 |
| 输出限幅 | `outputLimit` | 关闭 | 限制最终输出范围 |
| 输出死区 | `deadband` | 0 时关闭 | 小输出直接置 0 |
| 抗积分饱和 | `antiWindupGain` | 0 时只做普通积分 | 输出饱和时修正积分累积 |

这些工具放在 PID 控制单元里，是为了让通用控制器直接具备输入整形、输出保护和状态观测能力。它们不是上层业务逻辑，也不包含硬件接口。

## 设计边界

- 控制器单元不依赖上层应用。
- 常规入口保持 `pid_init()` 和 `pid()`；需要跟踪下游最终输出时使用 `pid_eval()` 与 `pid_track()`。
- P / PI / PD / PID 不需要模式枚举，由 `kp / ki / kd` 是否为 `0.0f` 自动决定。
- PI 和 PID 只要 `ki != 0.0f`，都会执行 back-calculation 积分抗饱和。
- P 和 PD 没有积分状态，因此不执行积分抗饱和。
- 内置 filter/ramp/limit/deadband 是可选控制工具，不是上层业务。

## 积分抗饱和参考模型

随包参考模型：

```text
simulink/models/reference/antiwindup_complete_reference.slx
```

该模型的积分抗饱和拓扑为：

```text
e = reference - feedback
uc = P/I 组合后的限幅前控制量
u  = saturation(uc)

积分输入 = e - Kaw * (uc - u)
         = e + Kaw * (u - uc)
```

对应 C 实现：

```c
antiWindupError = limitedOutput - rawOutput;
integralNext = integral + ki * (error + antiWindupGain * antiWindupError) * Ts;
```

其中 `rawOutput` 对应模型里的 `uc`，`limitedOutput` 对应模型里的 `u`，`antiWindupGain` 对应模型里的 anti-windup 反馈增益。当前实现是离散控制写法，积分修正进入下一拍状态；参考模型是连续 Simulink 模型，因此严格逐采样一致性需要固定步长离散化后再对比。

## 初始化函数

建议每个 PID 实例先调用 `pid_init(&controller)`，再覆盖工程参数。初始化函数会清零输入和状态、关闭限幅/斜率/死区等可选工具、设置默认控制频率和抗饱和默认增益。

注意：`pid_init()` 不代表控制器已经完成调参。实际工程仍应明确覆盖 `kp / ki / kd / controlFreq / outputLimit` 等关键参数。

## 最少必配参数

快速使用时至少配置：

1. `config.controlFreq`：控制频率，单位 Hz，必须大于 0。
2. `config.kp / config.ki / config.kd`：PID 参数；不用的通道填 `0.0f`。
3. `config.outputLimit`：输出限幅，单位同输出；建议必须打开。

当 `ki != 0.0f` 时建议额外配置：

4. `config.integralLimit`：积分项限幅，单位同输出。
5. `config.antiWindupGain`：抗积分饱和增益，单位为被控量单位/输出单位；标幺时为 `pu/pu`。

## 最小示例

```c
#include "src/pid.h"

Pid controller;
float output;

(void)pid_init(&controller);

controller.config.controlFreq = 1000.0f;
controller.config.kp = 0.8f;
controller.config.ki = 12.0f;
controller.config.kd = 0.0f;
controller.config.outputLimit.enable = true;
controller.config.outputLimit.min = -1.0f;
controller.config.outputLimit.max = 1.0f;
controller.config.integralLimit.enable = true;
controller.config.integralLimit.min = -0.8f;
controller.config.integralLimit.max = 0.8f;
controller.config.antiWindupGain = 1.0f;

controller.input.setpoint = 1000.0f;
controller.input.feedback = 920.0f;
controller.input.feedforward = 0.0f;

output = pid(&controller);
```

## 复位方式

不提供单独 `pid_reset()`。需要复位时直接清状态：

```c
controller.state = (PidState){0};
```

需要整体重置时：

```c
(void)pid_init(&controller);
```

## 多实例使用方式

```c
typedef struct {
    Pid loop0;
    Pid loop1;
    Pid loop2;
} ControlGroup;

ControlGroup group[2] = {0};

(void)pid_init(&group[0].loop0);
(void)pid_init(&group[1].loop0);

group[0].loop0.input.setpoint = target0;
group[0].loop0.input.feedback = feedback0;
cmd0 = pid(&group[0].loop0);

group[1].loop0.input.setpoint = target1;
group[1].loop0.input.feedback = feedback1;
cmd1 = pid(&group[1].loop0);
```

PID 内核只处理 `setpoint - feedback`。

## 目录

```text
src/pid.h
src/pid.c
examples/minimal_example.c
examples/multi_instance_example.c
tests/
simulink/
docs/design.md
reports/
```


## 最终输出跟踪

下游还有矢量约束、执行器缩放或其他最终输出处理时，可使用两阶段接口：

```c
PidStatus pid_eval(const Pid *controller, PidStep *step);
PidStatus pid_track(Pid *controller, float appliedOutput, PidStep *step);
```

调用方持有 `PidStep`。评估成功后，`step.next.rawOutput` 是原始输出，`step.next.output` 是已有单轴工具处理的输出；原实例及积分均未改变。下游完成全部约束后，把最终实际施加值交给一次 `pid_track()`；它使用旧积分、当周期误差和原始输出计算回算，最后执行积分限幅并发布状态。不能先用 `pid()` 更新积分，再追加一次外部回算。

同一实例只允许一个活动候选，评估到跟踪之间不改实例的配置、输入或状态，不混用旧入口，也不复制活动候选。候选可以直接丢弃或重新评估覆盖。跟踪校验归属和原对象字节快照，每次尝试后均失效，防止重复、跨实例及交错使用。候选存储不得与原实例重叠；原实例地址和生命周期覆盖评估至跟踪。

新路径增加 `PID_ERR_NUMBER`（非有限数或算术溢出）与 `PID_ERR_STEP`（候选失效、对象不同或原对象已改变）。失败时原实例连同 `state.status` 保持不变，必须使用返回码判定成功。所有数值标量须有限；未启用限幅的边界不参与检查。最终施加值不再被 `outputLimit` 重复限幅，`state.output` 记录该值。

`PidLimit/PidInput/PidConfig/PidState/Pid` 的成员类型和顺序不变；既有 `pid()`、状态码和非法配置处理保持兼容。新旧路径共用输出评估与积分公式，不引入被控对象或硬件依赖。

## 实际 C 验证与共享构建

在本目录用 CMake 配置后运行 CTest，可执行 `pid_runtime`：两阶段评估/跟踪、单次回算与积分裁剪顺序、持续外部饱和和恢复、错误原子性、轻量先积分 PI，以及 3,000 周期的新旧成功路径等价。测试 C 文件为 UTF-8；src 与 examples 保持原 GBK，当前 `pid.c/pid.h` 均为 LF，原文件字节不变。

```text
cmake -S . -B build-host -DBUILD_TESTING=ON
cmake --build build-host
ctest --test-dir build-host --output-on-failure
```

[controller 级共享构建](../CMakeLists.txt)还包含修改前实际 C 的固定 PID/FOC 状态基线、调制与变换测试、六个现有示例宿主。原 `pid_controller` 目标保持可独立链接，FOC 通过传递依赖复用它。[固定基线来源](../tests/fixtures/README.md)可查采集提交和源码哈希；Python 模型及静态检查继续保留，不能代替这些实际 C 结果。

## no-compile 验证

本包不编译 C。验证脚本只做：

- Python 行为镜像测试；
- C API 静态检查；
- 控制器响应性能仿真；
- Simulink 脚本存在性检查；
- C 源码 GBK 编码检查；
- 第三方项目名脱敏检查；
- 单位与标幺说明检查。

运行：

```bash
python tests/run_no_compile_validation.py
```
