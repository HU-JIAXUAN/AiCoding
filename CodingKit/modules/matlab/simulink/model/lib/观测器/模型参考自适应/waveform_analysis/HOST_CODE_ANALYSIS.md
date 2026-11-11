# MRAS状态更新函数：主机代码与类型回归

| 字段 | 本次取值 |
|---|---|
| 模型文件 | src/MrasObserver.slx；主机入口src/mras_step.m |
| 参数文件 | parameter/mras_parameters.m、mras_test_parameters.m、mras_host_test_parameters.m |
| 采样周期 | 50 μs |
| 求解器/步长 | 解析连续输入，显式离散状态每50 μs更新；主机函数直接执行，无Simulink连续求解器 |
| 工况 | SPMSM：.5 Ω、1 mH、.035 Wb，真实电角速度600 rad/s，初角.7 rad，id=0/iq=2 A；0–.1 s/2001点，.08 s后评分 |
| 数据文件 | waveform_analysis/host_codegen/physical_fixture.mat、mex_double_trace.mat、mex_single_trace.mat、sil_double_trace.mat及host_verification.json |

## 实现与修正

R2026b Update 1、MinGW64 C 14.2.0，从正式`mras_step.m`实际生成并执行double/single MEX与独立double C库SIL。Screener的UnsupportedCalls/Messages均为0。独立解析轨迹的电压/电流进入算法，真实角/速度只评分。

首次single MEX因`count=0`的double推断与分支single赋值冲突失败，保留[原失败](host_codegen/initial_single_failure.json)。修正为`count=cast(0,'like',state)`并同步SLX的Update块，[源码/连接/位置记录](host_codegen/library_update_verification.json)保留。控制公式、门限和默认精度保持。

## 实际结果

| 阶段 | 最大相对状态误差 | 角误差RMS（电角rad） | 速度误差RMS（电角rad/s） | 窗口valid比例 |
|---|---:|---:|---:|---:|
| double MEX | 0 | 8.6222763×10⁻⁶ | .0031433111 | 1 |
| single MEX | 0 | 1.0357218×10⁻⁵ | .0035382344 | 1 |
| double SIL | 4.0856207×10⁻¹⁴ | 8.6222763×10⁻⁶ | .0031433111 | 1 |

比较口径及21列单位见[参数页](../parameter/README.md#主机代码检查配置与数据)。生成程序与同类型MATLAB比较，single并非与double逐位相同；资格计数、方向、故障额外要求完全一致，且通过独立物理误差门限。[报告](host_codegen/host_verification.json)、[日志](host_codegen/formal_run.log)及四份MAT保存；编译目录/二进制是可重建缓存，报告中的临时路径保留为历史位置。

原24项lib的26列与10项MRAS物理App六组轨迹重放逐点差为0，不累计新MIL。[统一核对](typed_verification.json)绑定当前源/模型指纹；原始数据复用`results.mat`（运行验证后生成）及[App results.json](../../../../app_models/Sensorless/sensorless_foc/waveform_analysis/mras/results.json)，不重复归档相同的大体积MAT。

## 重新运行

MATLAB当前目录切到工程根simulink；R2026b需MATLAB Coder、Embedded Coder及已配置的C编译器：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
addpath(fullfile(pwd,'model','lib','观测器','模型参考自适应','waveform_analysis'));
outputDir = tempname;
report = run_mras_host_validation(outputDir);
assert(strcmp(report.status,'passed'));
```

`initialize_motor_paths`位于工程`docs/scripts`。脚本要求新输出目录以保护旧结果，配置修改`parameter/mras_host_test_parameters.m`；结束/失败时恢复原工作目录/路径、释放本次SIL/MEX，不打开模型或Scope。输出留在outputDir，供分析后处理。

本项只覆盖21状态更新M函数；未验证输出适配器、完整SLX/App的single类型、App SIL、C2000构建/PIL、执行时序或真实电机。工程SLX默认仍使用double。
