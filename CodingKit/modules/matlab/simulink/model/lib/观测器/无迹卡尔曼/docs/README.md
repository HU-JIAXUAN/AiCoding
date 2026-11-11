# UKF原理与公式

[公式推导.md](公式推导.md)从定子电压/磁链开始，推导四状态SPMSM、离散过程、线性电流校正、9点UT、圆周统计、数值修复与资格计数，并对应实际模型接口。

| 入口 | 内容 |
|---|---|
| [库模型](../src/UkfObserver.slx) | UKF积木，供其他模型调用 |
| [验证模型](../src/UkfObserverTest.slx) | 独立输入、10组Scope和50列日志 |
| [参数与信号](../parameter/README.md) | 默认值、状态、输出和实际通道 |
| [搭建过程](../build_process/STEPS.md) | 从块到状态的连接顺序 |
| [运行方法](../build_process/USAGE.md) | Run、调参、子集验证和读波形 |
| [结果分析](../waveform_analysis/ANALYSIS.md) | 29项MIL、21项数值及比较范围 |

[模块入口](../README.md)
