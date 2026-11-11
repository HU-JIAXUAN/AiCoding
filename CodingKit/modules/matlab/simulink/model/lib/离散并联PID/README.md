# DiscretePID

## 用途

可复用离散 PID 库模块，采用并联形式、前向欧拉积分、一阶滤波微分（后向欧拉）、输出限幅和回算抗积分饱和，包含 enable、reset 及积分/微分诊断输出。默认 Kd=0，作为 PI 使用。首版完成电脑上的模型在环（MIL）验证，使用无量纲 double 参数。

库文件内的 Controller 是复用入口。测试模型通过库链接调用它。内部按 OutputStage（输出计算）、IntegralUpdate（积分更新）和 DerivativeFilter（滤波微分）划分。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/DiscretePID.slx](src/DiscretePID.slx) | 已创建 |
| [src/DiscretePIDTest.slx](src/DiscretePIDTest.slx) | 已创建 |
| [build_process/DESIGN.md](build_process/DESIGN.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/initialize_discrete_pid_test.m](build_process/initialize_discrete_pid_test.m) | 已创建 |
| [parameter/discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) | 已创建 |
| [waveform_analysis/run_discrete_pid_validation.m](waveform_analysis/run_discrete_pid_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[模型文件](src/README.md) · [搭建过程](build_process/README.md) · [波形分析](waveform_analysis/README.md) · [参考资料](ref/README.md) · [参数](parameter/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| e | 输入 | 1（首版无量纲误差） | double | Ts |
| enable | 输入 | 1 | boolean | Ts |
| reset | 输入 | 1 | boolean | Ts |
| u | 输出 | 1（首版无量纲命令） | double | Ts |
| u_unsat | 输出 | 1 | double | Ts |
| saturated | 输出 | 1 | boolean | Ts |
| x_i | 输出 | 1 | double | Ts |
| x_d | 输出 | 1 | double | Ts |

active = enable && !reset。active 时：

~~~text
s[k] = Tf/(Tf+Ts)*s[k-1] + (e[k]-e[k-1])/(Tf+Ts)
x_d[k] = Kd*s[k]
v[k] = Kp * e[k] + x[k] + x_d[k]
u[k] = clamp(v[k], UMin, UMax)
x[k+1] = x[k] + Ts * (Ki * e[k] + Kaw * (u[k] - v[k]))
u_unsat[k] = v[k]
saturated[k] = (u[k] != v[k])
x_i[k] = x[k]
~~~

禁能或复位时，u=0、u_unsat=0、saturated=false，x_i=X0，下一拍状态写入 X0。reset 为同步电平复位，优先于 enable；重新使能第一拍从 X0 计算。禁能时强制零输出，不受 UMin/UMax 限制。x_i 是当前积分贡献的诊断量。

微分支路先滤波误差变化率，再乘 Kd，因此 Kd=0 时 x_d 严格为零。滤波斜率初值与 inactive 值为 0；上一误差初值为 0，之后每拍记录当前 e，包括禁能/复位期间。当前微分作用在误差上：启动时非零误差、误差阶跃或重新使能时的误差变化可能产生微分响应；这与只对测量值微分不同。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| Kp | 1 | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| Ki | 1/s | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| Kd | s | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| Tf | s | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| Ts | s | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| UMin / UMax | 1 | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| X0 | 1 | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |
| Kaw | 1/s | [discrete_pid_parameters.m](parameter/discrete_pid_parameters.m) |

默认值和修改方式见[参数说明](parameter/README.md)。Ki 尚未乘 Ts；离散化在模块内部完成。Kaw=0 关闭回算。掩码默认引用调用模型工作区的 pidCfg 字段；未来两个 PI 实例可以通过各自掩码表达式绑定不同参数结构。

[parameter/README.md](parameter/README.md) 同时列出输入、内部状态/计算量、输出及 Scope 第 1–9 通道的含义、单位和来源。具体运行、修改参数、构造输入和读波形的操作见 [USAGE.md](build_process/USAGE.md)。

## 验证

测试模型：[DiscretePIDTest.slx](src/DiscretePIDTest.slx)。批量入口：[run_discrete_pid_validation.m](waveform_analysis/run_discrete_pid_validation.m)。结果：[分析记录](waveform_analysis/ANALYSIS.md)、`results.mat`（运行验证后生成）、[指标](waveform_analysis/metrics.json)。

在 MATLAB 中执行（可从任意当前目录运行）：

~~~matlab
moduleDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink/model/lib/离散并联PID";
addpath(fullfile(moduleDir,"waveform_analysis"));
summary = run_discrete_pid_validation();
open_system(fullfile(moduleDir,"src","DiscretePIDTest.slx"));
~~~

直接打开测试模型点击 Run，可运行默认饱和恢复工况；双击 Waveforms 看九通道数据。打开库后，右击 Controller → Mask → Look Under Mask 查看内部。

修改算法时，在 DiscretePID 库编辑器中解锁库，再修改 Controller 的源块并保存；随后重跑验证入口。测试模型保留 PIDUnderTest 的库链接，避免修改源块后测试仍运行旧副本。

R2026a Update 3 下 12 个工况通过：原有 PI 工况加微分阶跃、PID 斜坡和 PID 禁能/复位。Kd=0 的 8 项官方 PI 对照及 Kd>0 的 2 项官方 PID 对照均通过，10 项输出最大差值约 7.91e-16；禁能/复位单独验证。原有 9 项 PI 工况的前八个记录通道与修改前数据最大差值为 0。固定 ±0.02 误差带内的饱和恢复耗时仍为回算 0.514 s、关闭回算 1.820 s。

当前范围为 double、1 ms 固定步长 MIL。single、代码生成、SIL/PIL、C2000 执行时间及实机尚未验证。

[返回模型目录](../../README.md) · [返回工程入口](../../../README.md)

[抗积分饱和对照](../../../docs/validation/ANTI_WINDUP_COMPARISON.md)比较现有回算与参考 demo 的等效接法。
