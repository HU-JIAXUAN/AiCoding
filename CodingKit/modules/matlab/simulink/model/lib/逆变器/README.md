# SVPWM 与平均逆变器

## 用途

计划步骤09。采用最大/最小相参考注入共同分量的居中SVPWM等价实现。平均逆变器用占空比扣除均值后乘母线电压。调制命令duty和执行后的duty分别记录。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/Inverter.slx](src/Inverter.slx) | 已创建 |
| [src/InverterTest.slx](src/InverterTest.slx) | 已创建 |
| [parameter/inverter_parameters.m](parameter/inverter_parameters.m) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/run_inverter_validation.m](waveform_analysis/run_inverter_validation.m) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| `results.mat`（运行验证后生成） | 已创建 |
| [waveform_analysis/metrics.json](waveform_analysis/metrics.json) | 已创建 |

[src](src/README.md) · [搭建过程](build_process/README.md) · [参数/Scope](parameter/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| SVPWM.alpha / beta | 输入 | V，相峰值 | double | 继承 |
| SVPWM.duty_a / duty_b / duty_c | 输出 | 1 | double | 继承 |
| SVPWM.common_mode | 输出 | V | double | 继承 |
| Average.duty_a / duty_b / duty_c | 输入 | 1 | double | 继承 |
| Average.va / vb / vc | 输出 | V，对浮动中性点 | double | 继承 |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| inverterCfg.Vdc | V | [inverter_parameters.m](parameter/inverter_parameters.m) |
| inverterCfg.MinDuty | 1 | [inverter_parameters.m](parameter/inverter_parameters.m) |
| inverterCfg.PwmTs | s | [inverter_parameters.m](parameter/inverter_parameters.m) |
| inverterCfg.LinearLimit | V | [inverter_parameters.m](parameter/inverter_parameters.m) |

## 验证

R2026a下4个工况通过。入口：[run_inverter_validation.m](waveform_analysis/run_inverter_validation.m)。`results.mat`（运行验证后生成）、[分析](waveform_analysis/ANALYSIS.md)与[指标](waveform_analysis/metrics.json)均已保存。打开InverterTest.slx点击Run；调参和数据读取见[教程](build_process/USAGE.md)。

每轮实验内母线恒定；平均模型没有三相开关纹波、器件动态和采样窗口。超范围输入采用钳位，未实现专门过调制策略。

[模型目录](../../README.md) · [工程入口](../../../README.md)
