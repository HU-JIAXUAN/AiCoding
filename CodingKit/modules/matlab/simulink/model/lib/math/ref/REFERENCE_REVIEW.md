# 本地参考核对记录

核对日期：2026-11-08。方法：只读检查 SLX/ZIP 内 XML，没有运行原始模型，也没有改写参考文件。

## 主参考 chensha

来源：`F:\Study\Motor Control\网上相关资源\chensha\第3部分——PMSM三闭环位置控制(新3)\第三部分——PMSM三闭环位置控制(新)\三闭环位置控制仿真\Positionloop_control.slx`。

| 已核对部分 | 原模型内容 | 本模块采用方式 |
|---|---|---|
| Clark | α=(a−0.5*(b+c))*2/3，β=(√3/2)*(b−c)*2/3 | 系数一致，用 Gain/Sum 展开，新增 zero=(a+b+c)/3 |
| Park | d=α*cosθ+β*sinθ，q=−α*sinθ+β*cosθ | 符号与 d 轴对齐约定一致，用 Product 与 Sum 展开 |
| Anti_Park | 两条表达式为 cosθ*d−sinθ*q、sinθ*d+cosθ*q；子系统内有 From 取角度 | 使用同一逆矩阵，θ 改为明确的第三输入端口；端口按 d、q、θ 排列 |

原参考的 Clark 仅输出 αβ，适用于零序可忽略的控制链。本模块保留独立零序，使非平衡/含共模输入的完整往返关系可检查。角度从显式端口传入，便于在同一采样时刻核对。

## 辅助参考 MBD

来源：`F:\Study\Motor Control\MBD\Simulink_demo\14.Park & AntiPark.zip`，其中模型为 `14.Park & AntiPark/1.Park & AntiPark/Model/ParkAntiPark.slx`。

已确认包含 Park_test、Park、AntiPark 子系统。此次仅做结构定位，没有运行该模型或采用其 STM32G4 工程配置；其内部全部角度格式、整套部署行为未作为本模块已验证结论。

## 数值依据与验证边界

矩阵与 d 轴对齐公式同时核对 [MathWorks Clarke](https://www.mathworks.com/help/mcb/ref/clarketransform.html)、[Park](https://www.mathworks.com/help/mcb/ref/parktransform.html)及反变换页面。实际验证对象是本工程保存的两个 SLX，通过解析矩阵、独立 abc→dq 公式、手算轴向锚点与随机输入比较。没有把“原 demo 可运行”或“官方块数值对照已执行”作为当前结果。

[返回参考索引](README.md)
