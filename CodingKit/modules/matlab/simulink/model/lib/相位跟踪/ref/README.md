# 参考资料

| 资料 | 来源 |
|---|---|
| 《永磁同步电机无位置传感器控制》2.5.1–2.5.3，印刷36–38 / PDF65–67：相位跟踪与物理量观测分离；包角PLL与书中正弦鉴相器的差异 | [原文件、章节及采用说明](../../../../docs/references/BOOK_SENSORLESS_DESIGN.md) |
| 本工程 PLL/观测器接口及建设顺序 | [SENSORLESS_PLAN.md](../../../../docs/plans/SENSORLESS_PLAN.md) |
| MathWorks 估算器调参背景 | https://www.mathworks.com/help/mcb/gs/tuning-sensorless-position-estimators.html |
| PI、包角与离散更新推导 | [本模块搭建步骤](../build_process/STEPS.md) |
| MathWorks Mask参数与求值规则 | https://www.mathworks.com/help/simulink/ug/control-masks-programmatically.html |
| MathWorks 参数传入Mask内部 | https://www.mathworks.com/help/simulink/ug/calculate-values-used-under-the-mask.html |

PLL 是本项目按相位误差增益为 1 设计的标准块实现，不宣称逐块复刻官方内部算法。暂无复制的外部参考模型。
