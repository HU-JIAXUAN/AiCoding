# DiscretePID 参考资料

本地参考文件：暂无。

| 资料 | 来源 |
|---|---|
| Discrete PID Controller：积分方法、回算抗饱和 | [MathWorks](https://www.mathworks.com/help/simulink/slref/discretepidcontroller.html) |
| From Workspace：数据格式、采样与末尾行为 | [MathWorks](https://www.mathworks.com/help/simulink/slref/fromworkspace.html) |
| SimulationInput：单次仿真参数覆盖 | [MathWorks](https://www.mathworks.com/help/simulink/slref/simulink.simulationinput.html) |
| Unit Delay：离散状态保存 | [MathWorks](https://www.mathworks.com/help/simulink/slref/unitdelay.html) |

本模块用标准块独立搭建，官方 Discrete PID Controller 用作数值对照。Kd=0 工况使用官方 PI 模式，Kd>0 工况使用官方 PID 模式；统一 Parallel、积分 Forward Euler、微分滤波 Backward Euler、相同 Ts/限幅/back-calculation，滤波系数 N=1/Tf。enable/reset 按本模块约定单独验证。

[搭建记录](../build_process/STEPS.md) · [返回模块](../README.md)
