# P650 LaunchPad 目标计划

角色：当前已有硬件，作为首个 C2000 板上验证目标。按 LAUNCHXL-F28P65X / F28P650D CPU1 规划；实际器件完整型号和板卡修订在接入时核对。

## 接入边界

复用公共控制核；实际 ADC/PWM/反馈和故障接入在对应的 model 实机装配模块中实现，板级数值配置放在该模块自己的 parameter 中。当前只有目标说明，开始接入时再建立模块。先 CPU1，CLA/CPU2 仅在有明确任务或测量收益后增加。

P650 LaunchPad 是控制板，不自动提供所需电机功率级。功率板、电机、反馈、采样方式和连接仍待明确，本计划不预先指定引脚或额定限制。

## 后续要核对的项目

| 项目 | 内容 |
|---|---|
| 目标与工具 | MATLAB/Blockset、CCS/CGT/C2000Ware、目标器件、调试连接 |
| 板级电路 | 时钟、PWM 输出/极性、ADC 通道/量程、反馈与禁能/故障信号 |
| 时序与内存 | SOC/EOC、控制触发、shadow load、反馈年龄、链接/Flash/RAM |
| 证据 | 只生成/编译 → SIL/PIL → 实际采样与输出 → 基础电机闭环 |

每一级只声明实际通过的内容。PIL 函数时间不能自动代表整个 ISR 的 deadline 已满足。

器件资料更正：F28P650DK 是两个 C28x 与一个 CLA，不能按双 CLA 规划。[TI 器件资料](https://www.ti.com/product/TMS320F28P650DK/part-details/F28P650DK9ZEJR)、[LaunchPad 页面](https://www.ti.com/tool/LAUNCHXL-F28P65X)。
