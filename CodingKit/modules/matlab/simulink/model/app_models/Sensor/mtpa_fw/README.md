# MTPA与弱磁整机算法

## 用途

本App归Sensor，控制使用仿真位置/速度反馈；本目录归类不代表已完成真实位置传感器接入。通用积木继续引用model/lib。

将[lib/mtpa_fw](../../../lib/MTPA弱磁/README.md)的电流分配器与已有电流环、逆变器、采样时序和PMSM对象组装成速度闭环。这里保存完整App算法模型；MTPA/FW积木和独立组件测试仍属于lib。

## 文件

| 路径 | 状态 |
|---|---|
| [docs/README.md](docs/README.md) | 已创建 |
| [docs/公式推导.md](docs/公式推导.md) | 已创建 |
| [src/MTPAFWMotor.slx](src/MTPAFWMotor.slx) | 已创建 |
| [parameter/README.md](parameter/README.md) | 已创建 |
| [build_process/README.md](build_process/README.md) | 已创建 |
| [waveform_analysis/README.md](waveform_analysis/README.md) | 已创建 |
| [ref/README.md](ref/README.md) | 已创建 |

## 接口

| 名称 | 方向 | 单位 | 类型 | 采样周期 |
|---|---|---|---|---|
| experimentCfg速度/位置给定、refTestCfg转矩给定 | 输入工况 | rad/s / rad / N·m | double | 给定保持；电流100µs、外环1ms |
| Enable / Reset | 输入工况 | 1 | double/逻辑兼容 | 100µs |
| trace | 输出记录 | 混合SI，详见参数页 | double，74列 | 100µs |

## 参数

| 名称 | 单位 | 定义文件 |
|---|---|---|
| experimentCfg | SI | [experiment_parameters.m](../experiment/parameter/experiment_parameters.m) |
| refCfg / refTestCfg及App工况覆盖 | SI | [reference_case_parameters.m](../../../lib/MTPA弱磁/parameter/reference_case_parameters.m) |
| 电机/电流/逆变器/外环配置 | SI | [全部参数与Scope说明](../../../lib/MTPA弱磁/parameter/README.md) |

## 验证

整机7项MIL随第15步25项共同验证保留，见[波形索引](waveform_analysis/README.md)。本轮目录迁移后的打开、库链接和仿真记录见[迁移记录](../../../../docs/history/MODEL_LAYOUT_MIGRATION.md)。未进行C2000目标验证。

[App目录](../../README.md) · [model目录](../../../README.md)

[Sensor分类](../README.md) · [App分类](../../README.md)
