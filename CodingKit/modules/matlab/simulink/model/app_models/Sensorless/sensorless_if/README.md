# I-f 无位置开环 PMSM App

## 用途

软件角度驱动虚拟 dq 电流 PI，运行给定为 d 轴 3 A、q 轴 0 A。整机包括观察、对齐、频率斜坡、保护、逆变器和 SPMSM 对象。对象实际转速及转子电角度只接记录、Scope 和相位差；同步参考不保证转子始终跟随。

## 文件

| 目录 | 内容 |
| --- | --- |
| [src](src/README.md) | 可直接运行的 [ SensorlessIF.slx](src/SensorlessIF.slx) |
| [parameter](parameter/README.md) | 可执行 M 参数、信号与 Scope 顺序 |
| [build_process](build_process/README.md) | 搭建、重建和操作步骤 |
| [waveform_analysis](waveform_analysis/README.md) | 默认波形、边界工况与验收 |
| [ref](ref/README.md) | 理论与示例来源 |
| [docs](docs/README.md) | 算法说明和公式推导 |

## 接口

本 App 从内部工况源读取电频率、使能、复位、负载转矩和实际母线电压。结果由各 Scope、`app_trace`（49 列）和 `physical_trace`（4 列）输出。[公用命令库](../../../lib/无感启动/README.md)可被其他模型单独调用。

## 参数

默认从 [if_app_parameters.m](parameter/if_app_parameters.m) 加载。控制 62.5 μs，对象 12.5 μs；电频率 40 Hz、4 对极对应 600 rpm。运行前先执行[路径初始化与使用步骤](build_process/USAGE.md)。

## 验证

R2026b Update 1，13 项 MIL 通过，另做对象半步长复核。默认末窗速度误差 RMS 0.614358 rad/s，完整快步长电流峰值 3.02559 A。[分析](waveform_analysis/ANALYSIS.md)区分跟随、保护以及预期失步反例。本模块为独立开环 App；观测器接管与实机验证待后续。
