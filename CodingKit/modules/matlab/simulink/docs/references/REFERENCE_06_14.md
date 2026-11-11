# 06–14 参考资料核对

主参考为本地 chensha。只读查看 `Positionloop_control.slx` 的SLX压缩包和 `simulink/blockdiagram.xml`，未执行旧模型、未修改或复制其文件。

原始路径：

```text
F:\Study\Motor Control\网上相关资源\chensha\第3部分——PMSM三闭环位置控制(新3)\第三部分——PMSM三闭环位置控制(新)\三闭环位置控制仿真\Positionloop_control.slx
```

本次核对到了 Clark、Park、Anti_Park、SVPWM、Speed 子系统，以及来自 powerlib 的 Permanent Magnet Synchronous Machine、Universal Bridge、DC Voltage Source、powergui。原模型使用电机与桥的物理库组合；本次为了分别观察电气/机械状态与执行限制，独立建立基础块dq方程和平均逆变器。相序和Park符号沿用[math的核对记录](../../model/lib/math/ref/REFERENCE_REVIEW.md)。没有把“看到了相同模块名”当成动态模型等价证明。

辅助资料仍为 MBD 下的 `Simulink_demo/14.Park & AntiPark.zip`，本次没有运行该包或采用其STM32部署目录。

| 主题 | 本次使用的官方来源 | 用途 |
|---|---|---|
| PMSM | [PMSM HDL](https://www.mathworks.com/help/mcb/ref/pmsmhdl.html) | 核对dq微分方程、磁阻转矩、极对数和机械方程 |
| PI回算 | [PID Controller](https://www.mathworks.com/help/simulink/slref/pidcontroller.html) | 回算/跟踪概念；本次电流双轴PI使用可见基础块实现 |
| FOC组合 | [Design Field-Oriented Control Algorithm](https://www.mathworks.com/help/mcb/ug/design-field-oriented-control-algorithm.html) | 电流环与速度环职责、分步验证思路 |
| 调制 | [PWM Reference Generator](https://www.mathworks.com/help/mcb/ref/pwmreferencegenerator.html) | αβ/abc参考、SVM和duty接口 |
| 采样 | [Zero-Order Hold](https://www.mathworks.com/help/simulink/slref/zeroorderhold.html) | 连续到离散保持；多任务部署不能由此推断并发数据一致性 |
| dq前馈 | [PMSM FeedForward Control](https://www.mathworks.com/help/mcb/ref/pmsmfeedforwardcontrol.html) | 核对电角速度与两个前馈项符号 |
| 死区 | [Dead-Time Compensator](https://www.mathworks.com/help/mcb/ref/deadtimecompensator.html) | 补偿插入点和过零电流极性问题；自建线性平滑与官方滞环不是同一算法 |
| 单轮覆盖 | [SimulationInput](https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.html) | 单轮参数覆盖和SimulationOutput |

本地运行环境是R2026a Update 3，在线帮助当前显示R2026b；本次没有依赖仅在新版本引入的建模块。没有执行官方块与新块的逐点等价测试。

电机、电源、死区与控制增益均明确作为自定义仿真夹具：Rs=0.5Ω、Ld=1mH、Lq=1.2mH、Flux=0.035Wb、4极对、J=0.0005kg·m²、B=0.0001N·m·s/rad、48V、2µs死区。没有将它们标为chensha测量数据或P650实际电机参数。各模块parameter保留唯一默认定义，每个case保存实际覆盖。

[实施记录](../history/BUILD_06_14.md) · [模型目录](../../model/README.md)
