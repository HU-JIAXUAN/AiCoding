# SPMSM电流模型MRAS

## 用途

按主要书籍12.2.2的电流模型实现位置/速度自适应估计。参考量为实测dq电流，可调模型从上一拍实测dq电流一步预测，d电流差经归一化和PI调节速度，再积分角度。适用于有足够基波激励且已有方向先验的SPMSM；零速不取得位置资格。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/MrasObserver.slx](src/MrasObserver.slx) | 已创建 |
| [src/MrasObserverTest.slx](src/MrasObserverTest.slx) | 已创建 |
| [src/mras_step.m](src/mras_step.m) | 已创建 |
| [src/mras_output.m](src/mras_output.m) | 已创建 |
| [build_process/STEPS.md](build_process/STEPS.md) | 已创建 |
| [build_process/USAGE.md](build_process/USAGE.md) | 已创建 |
| [waveform_analysis/ANALYSIS.md](waveform_analysis/ANALYSIS.md) | 已创建 |
| [parameter/mras_parameters.m](parameter/mras_parameters.m) | 已创建 |
| [parameter/mras_test_parameters.m](parameter/mras_test_parameters.m) | 已创建 |
| [parameter/mras_host_test_parameters.m](parameter/mras_host_test_parameters.m) | 已创建 |
| [waveform_analysis/run_mras_host_validation.m](waveform_analysis/run_mras_host_validation.m) | 已创建 |
| [waveform_analysis/HOST_CODE_ANALYSIS.md](waveform_analysis/HOST_CODE_ANALYSIS.md) | 已创建 |
| [waveform_analysis/typed_verification.json](waveform_analysis/typed_verification.json) | 已创建 |

[模型](src/README.md) · [参数](parameter/README.md) · [搭建](build_process/README.md) · [波形](waveform_analysis/README.md) · [参考](ref/README.md)

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| u_alpha/u_beta | 输入 | V | double | cfg.Ts |
| i_alpha/i_beta | 输入 | A | double | cfg.Ts |
| direction / enable / reset | 输入 | ±1或0 / 0/1 / 0/1 | double兼容 | cfg.Ts |
| theta / omega / valid | 输出 | 电角rad / rad/s / 0/1 | double | cfg.Ts |
| 预测/实测dq电流及归一化残差等 | 诊断输出 | 见参数页 | double | cfg.Ts，诊断一拍年龄 |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| 电机、采样、PI、滤波、限值和资格 | SI | [mras_parameters.m](parameter/mras_parameters.m) |
| 默认轨迹、噪声和评分窗口 | SI | [mras_test_parameters.m](parameter/mras_test_parameters.m) |
| 主机轨迹、物理评分和比较容差 | SI / 相对值 | [mras_host_test_parameters.m](parameter/mras_host_test_parameters.m) |

修改参数后调用`initialize_mras_test('MrasObserverTest')`；实例Mask引用独立配置结构体。

## 验证

R2026b完成24项独立MIL，以及两路不同Mask配置的并行实例检查；重新搭建与正式目录默认26列波形逐点相同。当前30 Hz设计频率覆盖了加速段持续资格，20→30 Hz修正前后数据保留。默认捕获36.55 ms；噪声、失配、延迟和拒绝条件见[波形分析](waveform_analysis/ANALYSIS.md)。上述为独立观测器验证。另有[物理App10项检查](../../../app_models/Sensorless/sensorless_foc/build_process/EXTENSION_USAGE.md)覆盖接管、拒绝和退出；状态更新M函数另已完成double/single MEX与double SIL，见[主机代码分析](waveform_analysis/HOST_CODE_ANALYSIS.md)；完整SLX/App的single转换、App SIL和实机未验证。类型修正后原24项lib与10项App重放逐点差为0，不重复累计新工况。
