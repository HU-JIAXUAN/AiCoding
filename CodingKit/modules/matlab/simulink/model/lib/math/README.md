# Math：Clarke/Park 与 SVPWM

## 用途

提供Clarke、Park、InversePark、InverseClarke四个坐标变换，以及新增的BlendDQ同坐标电流参考混合积木。统一采用幅值不变、abc 正相序、d 轴在零角度沿 α 轴的约定；电角度单位 rad。变换是无状态代数运算，继承调用者采样周期。首版数值类型为 double。

当前测试用三相电流 A 演示；同一线性变换可用于电压，使用时输入输出单位一致。反馈电流可走 abc→Clarke→Park；电压指令可走 dq→InversePark→αβ，后续按调制接口选择是否再用 InverseClarke 转为 abc。

[SVPWM](src/svpwm/README.md) 提供两电平逆变器的居中七段式和低侧钳位五段式。两种库均以 αβ 电压和实际母线电压为输入，输出三相占空比和共同分量。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/ClarkePark.slx](src/ClarkePark.slx) | 已创建 |
| [src/clarke/ClarkeTransforms.slx](src/clarke/ClarkeTransforms.slx) | 已创建 |
| [src/park/ParkTransforms.slx](src/park/ParkTransforms.slx) | 已创建 |
| [src/svpwm/seven_segment/SvpwmSevenSegment.slx](src/svpwm/seven_segment/SvpwmSevenSegment.slx) | 已创建 |
| [src/svpwm/five_segment/SvpwmFiveSegment.slx](src/svpwm/five_segment/SvpwmFiveSegment.slx) | 已创建 |
| [src/svpwm/SvpwmComparisonTest.slx](src/svpwm/SvpwmComparisonTest.slx) | 已创建 |
| [src/ClarkeParkTest.slx](src/ClarkeParkTest.slx) | 已创建 |
| [src/FrameBlendTest.slx](src/FrameBlendTest.slx) | 已创建 |
| [src/blend_dq.m](src/blend_dq.m) | 已创建 |
| [build_process/FRAME_BLEND.md](build_process/FRAME_BLEND.md) | 已创建 |
| [parameter/FRAME_BLEND.md](parameter/FRAME_BLEND.md) | 已创建 |
| [waveform_analysis/FRAME_BLEND.md](waveform_analysis/FRAME_BLEND.md) | 已创建 |
| [parameter/clarke_park_parameters.m](parameter/clarke_park_parameters.m) | 已创建 |
| [parameter/svpwm_test_parameters.m](parameter/svpwm_test_parameters.m) | 已创建 |
| [build_process/build_svpwm_models.m](build_process/build_svpwm_models.m) | 已创建 |
| [waveform_analysis/run_svpwm_validation.m](waveform_analysis/run_svpwm_validation.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/DESIGN.md](build_process/DESIGN.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_clarke_park_validation.m](waveform_analysis/run_clarke_park_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |

[模型](src/README.md) · [搭建过程](build_process/README.md) · [参数与 Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

每个子系统在库根可独立拖入使用。原四个变换的数值端口为标量。BlendDQ的start_current、closed_current、reference为2元素向量，theta_start/theta_control为rad标量，beta/enable/reset为无量纲标量；继承调用周期，输出属于theta_control坐标，详细接口及Scope见[参数页](parameter/FRAME_BLEND.md)。

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| Clarke.a / b / c | 输入 | 同一物理量；测试为 A | double | 继承调用者 Ts |
| Clarke.alpha / beta / zero | 输出 | 与输入相同 | double | 同一拍 |
| Park.alpha / beta | 输入 | 测试为 A | double | 继承调用者 Ts |
| Park.theta_e | 输入 | rad，电角度 | double | 与 αβ 同一采样时刻 |
| Park.d / q | 输出 | 与 αβ 相同 | double | 同一拍 |
| InversePark.d / q | 输入 | 测试为 A | double | 继承调用者 Ts |
| InversePark.theta_e | 输入 | rad，电角度 | double | 与 dq 同一采样时刻 |
| InversePark.alpha / beta | 输出 | 与 dq 相同 | double | 同一拍 |
| InverseClarke.alpha / beta / zero | 输入 | 同一物理量；测试为 A | double | 继承调用者 Ts |
| InverseClarke.a / b / c | 输出 | 与输入相同 | double | 同一拍 |
| SVPWM.alpha / beta / vdc | 输入 | V | double | 继承调用者 Ts |
| SVPWM.duty_a / duty_b / duty_c | 输出 | 1 | double | 同一拍 |
| SVPWM.common_mode | 输出 | V | double | 同一拍 |

zero=(a+b+c)/3，不经过 Park 旋转。三线制零和输入时它为零；重建一般三相量时需要保留。原四个变换没有积分、滤波、记忆状态或复位端口；BlendDQ另有同拍禁能/复位门控，但无记忆状态；这里的“同一拍”指模型中未加入整拍延迟，不是 MCU 执行耗时测量。

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 固定变换系数 2/3、1/3、1/√3、−1/2、√3/2 | 1 | [ClarkeTransforms.slx](src/clarke/ClarkeTransforms.slx) 内 Gain 块 |
| Ts / Duration | s | [clarke_park_parameters.m](parameter/clarke_park_parameters.m) |
| Amplitude | A，峰值 | [clarke_park_parameters.m](parameter/clarke_park_parameters.m) |
| FrequencyHz | Hz，电频率 | [clarke_park_parameters.m](parameter/clarke_park_parameters.m) |
| InitialAngleRad / AngleOffsetRad | rad | [clarke_park_parameters.m](parameter/clarke_park_parameters.m) |
| UseIndependentInverse / ZeroSequenceGain / RandomSeed | 1 | [clarke_park_parameters.m](parameter/clarke_park_parameters.m) |

BlendDQ测试参数blendTestCfg.Ts/Duration/Inputs定义于[blend_test_parameters.m](parameter/blend_test_parameters.m)，库块无配置Mask。核心变换系数固定；其余是测试场景参数，不是控制器整定增益。完整输入、过程变量、输出和四组 Scope/20 列数据说明见 [parameter/README.md](parameter/README.md)。

## 验证

SVPWM 对照测试通过 14 组输入。12 组扇区内部工况覆盖 24 V 和 48 V 下的六个扇区，其余两组检查零电压请求和过范围占空比钳位。线性工况的平均相电压最大重建误差为七段式 7.11e−15 V、五段式 3.55e−15 V。段数由实际仿真占空比按理想载波比较规则检查。 [运行方法](src/svpwm/README.md)

新增BlendDQ的两个场景（13个显式与500个随机向量）通过，物理坐标误差不超过3.56e-15A；原13项回归也在R2026b通过。见[新分析](waveform_analysis/FRAME_BLEND.md)、`frame_blend_results.mat`（运行验证后生成）、[指标](waveform_analysis/frame_blend_metrics.json)及[运行方法](build_process/FRAME_BLEND.md)。

```matlab
moduleDir = "F:/Study/AI/AiCoding/CodingKit/modules/matlab/simulink/model/lib/math";
addpath(fullfile(moduleDir,"src"),fullfile(moduleDir,"parameter"), ...
    fullfile(moduleDir,"build_process"),fullfile(moduleDir,"waveform_analysis"));
open_system(fullfile(moduleDir,"src","ClarkeParkTest.slx"));
summary = run_clarke_park_validation();
```

直接打开测试模型并点击 Run 可运行默认 5 A、50 Hz、0.1 s 的往返工况，Ts=0.0001 s。操作、调参和独立反变换示例见 [USAGE.md](build_process/USAGE.md)。

已通过 13 个工况，包括已知轴向、幅值、角偏差、负转速、零序、非平衡/谐波、随机逐拍输入及独立反变换。10 个完整往返工况最大重建误差约 3.55e-15 A，解析公式对照最大误差约 2.31e-14 A，容差 1e-12 A。另一个工况故意丢弃零序，验证预期的信息损失。

数值对照为解析矩阵与手算锚点，没有运行官方工具箱块或原始 demo。single、生成代码、SIL/PIL 和 C2000 实机尚未验证。结果见 [ANALYSIS.md](waveform_analysis/ANALYSIS.md) 和 [metrics.json](waveform_analysis/metrics.json)。

[返回模型目录](../../README.md) · [返回工程入口](../../../README.md)
