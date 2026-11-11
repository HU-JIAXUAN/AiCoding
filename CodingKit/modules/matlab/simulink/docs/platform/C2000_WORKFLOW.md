# C2000 包在 MATLAB/Simulink 中做什么

当前路线：已有 P650 LaunchPad 先验证，后续接入自制 F28388D 板。两者共用控制核，外设与部署配置分开。本轮只说明工作流，未连接、下载或改动硬件。

## 1. 从离线模型到板上控制

```text
电脑：控制算法 + 仿真电机 → 先理解与比较算法（MIL）
                         ↓ Coder 生成代码
电脑：生成代码 + 仿真电机 → 核对生成结果（SIL）
                         ↓ C2000 目标工具链
板卡：控制算法           + 电脑上的仿真输入/对象 → 板上算法测试（PIL）
                         ↓ 外设与板级接入
板卡：ADC/反馈 → 控制算法 → ePWM → 实际功率级/电机
```

离线搭 PI、Park 或数学电机时，基础 Simulink 就能承担许多工作。用到目标外设、目标优化、编译、下载、监控或 PIL 时，C2000 产品才进入核心路径。

## 2. 各种“包”分别负责什么

| 产品/工具 | 作用 | 在本项目里怎么用 |
|---|---|---|
| MATLAB / Simulink | 数值分析、画模型、执行仿真 | 搭控制器、数学 Plant 和实验 |
| Motor Control Blockset | 电机控制算法块、估计器和参考例程 | 可作官方对照；不替代自己理解接口与算法 |
| C2000 Microcontroller Blockset | C2000 外设块、目标设置、调度/工具链接入，以及相关目标验证工作流 | 对接 P650/F28388D 的 ADC、ePWM、反馈、构建与监控 |
| Simulink Coder / Embedded Coder | 从模型生成 C/C++，配置/优化嵌入式接口 | 导出控制核，配合 C2000 做目标优化与 PIL |
| Simscape Electrical | 电机/逆变器等物理网络建模 | 按非理想/开关研究需要引入，Plant 不随控制核上板 |
| CCS / TI CGT / C2000Ware | TI 调试、编译、器件驱动与例程资源 | 提供目标编译/调试和外设接入基础，版本需匹配 |

C2000 Blockset 的 ADC/ePWM 块表达目标外设配置与访问，并不自动提供你的功率级、传感器电路和电机的完整物理模型；具体块的仿真行为也要按文档核对。官方电机例程常另需 Motor Control Blockset 等产品。[C2000 产品说明](https://www.mathworks.com/products/ti-c2000-microcontroller.html)、[产品依赖](https://www.mathworks.com/support/requirements/c2000-microcontroller-blockset.html)

## 3. 生成整机，还是只生成算法

两条接入方式都保留：

- **整机模型生成**：在目标顶层放 ADC、ePWM、中断等 C2000 块与公共控制核。适合用现成 LaunchPad 学习完整目标工作流，实际例程与功率板仍需匹配。
- **控制核接入固件**：只导出算法函数，由 BSP/ISR 读取采样、调用控制核并提交 PWM。适合自制 F28388D 与已有驱动/特殊反馈。

先用 P650 学习/验证目标接入；到真实外设阶段，根据已有固件与官方例程选择具体装配。不同时维护两份控制律，也不把板级寄存器块放进公共 PI/FOC 库。

## 4. P650 与 F28388D 的实际讲究

| 事项 | 本平台的处理 |
|---|---|
| 共同的 C28x 控制路线 | 共用离散算法、接口、工况与指标；先统一 CPU1 执行 |
| 不同器件资源 | 外设数量/类型、引脚复用、ADC 通道、触发/中断、时钟、内存和启动配置分别核对 |
| 不同板级电路 | 分别记录电流/母线比例与 offset、反馈接口、PWM 极性和禁能/故障映射 |
| 不同加速器/多核 | F28P65x 的一个 CLA 在 CPU1 侧；F28388D 有双 CLA 与独立 CM，不能按相同布局假定迁移 |
| 不同目标构建 | 各自选择目标并重新生成/编译，不复制同一二进制，不继承另一块板的时序结论 |
| 自制板 | 支持某个芯片，不等于已经支持未知原理图；需填板级映射与验证资源所有权 |

TI F28P650DK 资料列出两个 C28x 和一个 CLA；F28388D 资料列出两个 C28x、两个 CLA 与独立 CM。初版不依赖这些附加核的数量。[F28P650DK 官方资料](https://www.ti.com/product/TMS320F28P650DK/part-details/F28P650DK9ZEJR)、[F28388D 官方资料](https://www.ti.com/product/TMS320F28388D)

本机R2026b已在`toolbox/c2b/tic2000/registry/targethardware/`下核对`TIF28P650DLaunchPad.xml`、`TIF28P65x.xml`和`TIF2838x.xml`三个目标登记。登记存在只说明目标入口可见；构建、连接、PIL与真实控制仍需实际验证。当前产品、MCP与121项MIL结果见[环境记录](../history/MATLAB_R2026B_MIGRATION.md)。[支持列表](https://www.mathworks.com/help/ti-c2000/gs/Supported-TI-C2000-Processors.html)

## 5. PIL、Monitor & Tune、Connected I/O 的区别

PIL 让算法在目标处理器上执行，由测试侧提供输入并比较输出；不等同于实际电机闭环。Monitor & Tune 用电脑查看/调整目标上正在运行的程序，实时控制仍在 MCU。Connected I/O 则让电脑仿真与板上 I/O 服务器交换数据，不应据此假定 Windows 已承担确定周期的高频 FOC。[官方 C2000 工作流](https://www.mathworks.com/help/ti-c2000/getting-started-with-c2b.html)

因此，这套模型既用于离线学习，也保留生成代码与目标验证能力；不能把“尽量基于 C2000 验证”理解成所有仿真块都要绑定 C2000 外设。

下一步按[环境清单](TOOLBOX_MATRIX.md)和[建设计划](../plans/IMPLEMENTATION_PLAN.md)推进。
