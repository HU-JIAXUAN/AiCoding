# 电机工程确定性工具

本资产提供有界只读源码检查和离散事件预算，不负责安装、发布、设备控制或另建工作流引擎。
控制数学在平台无关的 `timing.go`，C2000 driverlib 解释集中在 `c2000.go`。
`schema` 从实际 Go 输入/输出类型生成 JSON Schema；字段和结构不维护第二份清单。

从本目录运行：

```powershell
go test -v ./...
go test -run '^$' -bench . -benchmem ./...
go run . schema --kind timing-input
go run . schema --kind timing-report
go run . schema --kind inspection
go run . analyze --input example.json
go run . inspect --project TARGET_ROOT --file .ccsproject --file c2000.syscfg --file main.c --file device/device.h --file src/board/board_periph.c --file src/board/board_adc.c --file src/motor/motor_current.c
```

机器调用需要保留2/3/4退出码时，先 `go build -o motor-engineering.exe .` 再直接运行程序；
`go run` 自身会把子程序非零状态包装为Go进程失败，不能依赖它传递具体数值。

在上层仓库运行时用 `go -C CodingKit/tools/motor-engineering ...`。安装的 Skill 应通过上层提供的
资产根或 PATH 定位本工具，不从插件缓存向外猜路径。

## 已有能力与输入边界

`inspect` 一次只读取显式传入的文件，去重排序并记录 SHA256、行号和稳定输入摘要。
拒绝绝对文件名、越界/符号链接逃逸、超过128项或总计16 MiB的请求，每文件至多2 MiB。
不递归扫项目，不生成或修改目标文件，也不调用编译器、调试器或设备。

- 从 CCS/SysConfig 元数据读取实际 device、core、compiler 和匹配的 build option；参考文件名和注释不能选定芯片。
- 提取SysConfig实例属性与clockTree设置；CLB触发候选先解析显式硬件base绑定。`clb1`变量不保证对应CLB1，GLOBAL/LOCAL选择、生成结果和运行使能仍需复核。
- 提取 driverlib 调用、直接 `*Regs.*` 写入、相关常量；生成 PWM/SOC/EOC/ADCINT/vector/Shadow 源码关系和 ISR 可达调用图。
- 对简单显式函数指针赋值/字面回调注册补充 `SYNTACTIC_CALLBACK_CANDIDATE` 路径，保留注册调用与赋值来源；运行时条件、重绑定和间接表仍为未知，不能将可能路径当作确定执行路径。
- 常量求值支持简单整型/浮点四则、移位、括号和对象宏；保留 C 整数除法，拒绝歧义宏、递归宏、除零和无法表示的整数。
- PWM 候选遇到多次配置写入会变为 `AMBIGUOUS_WRITES`，不擅自猜最后运行状态。源码出现的 `sampleWindow` 和 `ACQPS` 保留原表达式，两者不能混用。

解析器是有限源码检查器，不是完整 C/C++ 前端。条件编译、函数指针、宏展开、数组循环中的 base
和多配置工程需读取同一构建配置的预处理源码、编译命令、MAP/反汇编后进一步核验；无法解析的
条目保持 `UNKNOWN`。`CONFIRMED_SOURCE_ONLY` 只确认源码内容，不能作为已烧录配置或硬件状态。
当前不自动推导任意 linker/MAP 的存储延迟、功率级拓扑、DMA 仲裁和嵌套中断 WCET。

## 时间模型

时间统一 ns，频率 Hz，角度为电角度 rad，角速度 rad/s。所有非可选字段必须出现；可空的
时延/边界用 `null` 表示未知，未知抖动不能默认为0。`sources` 放真实文件行号/摘要、测量捕获ID
或公式出处。例子明确为合成配置，不代表任何实际板卡。

`TBCLK = SYSCLK / epwm_div / clk_div / hspclk_div`。up/down 周期为 `(TBPRD+1)/TBCLK`，
up_down 周期为 `2*TBPRD/TBCLK`。ZERO、PERIOD、比较事件分别取对应相位；同刻的 SOC 计算结果
无法赶上同刻 Shadow Load。双采单更使用离下次装载最近的那次样本；双采双更逐半周期检查。
SOC分频大于1时，没有事件计数器初始相位便返回 `INSUFFICIENT_EVIDENCE`。

采样保持为 `acquisition_sysclk_cycles/SYSCLK`。C2000 driverlib `sampleWindow` 已是周期数；
直接寄存器 `ACQPS` 需加1。`result_latency_sysclk_cycles` 是从采样窗结束到结果可读的 `tLAT`，
不是只看 SAR 转换周期。`interrupt_lead_sysclk_cycles = tLAT - tINT`；late interrupt 也可能早于
结果锁存。例子使用 F2838x TRM SPRUII0F Table20-11 的12位、分频4数据：44和41 SYSCLK周期。
实际ADC分辨率、输入阻抗、最小采样窗和硅勘误必须匹配目标工程及器件。

`nonoverlap_bound` 对每个必需串行 SOC 叠加采样窗及结果延迟，再加触发和显式仲裁上界；这是
保守的无重叠序列预算。并行 ADC 分别计算后选真实依赖的最晚结果，不能把并行ADC串加。
连续SOC的流水重叠可使后续采样早于上个结果锁存；当前不提供精确流水模型，不能将此上界当作
测得延迟。若工程存在其他触发抢占，必须包含其仲裁上界，不能直接填0。

对每次更新计算：

```text
T_deadline = next_shadow_load - SOC
T_fixed_delay = result_ready - SOC - interrupt_lead + ISR_entry + fixed_delay + jitter_bound
T_available = T_deadline - T_fixed_delay - guard
margin = T_available - FOC_bound
```

ePWM ISR 则由显式 `isr_phase_ns` 决定入口，检查预读延迟后结果是否可用。
`fixed_delay_ns` 指 ISR 入口至读取必需 ADC 结果/开始本次控制计算的固定耗时，
`foc_bound_ns` 必须包含从该读取点到完成所有 Shadow 写入的控制/写入路径。
输出记录样本、读取、生效所属周期，PWM载波、电流更新率和未知闭环带宽分开记录。
装载代表命令生效；实际开关边沿还取决于比较/AQ/Trip与死区，不能当作同一时刻。

编码器分别填写物理锁存、接收、Park使用和PWM作用时刻，计算年龄及有界常速度预测误差
`0.5*a_max*age^2`。预测只允许一个所有者；过期、乱序或重复补偿返回明确诊断。

可选 `adc.acquisition_rc` 将已确认的一阶RC模型转换为采样窗下界。显式输入有效R(Ohm)、C(F)、
`resolution_bits`、`max_error_lsb`、`step_fraction`和`model_confirmed`；字段不可省略。
`t_RC=RC*max(0,ln(step_fraction*2^N/max_error_lsb))`，再与器件`minimum_acquisition_ns`取max。
满量程12bit、1LSB需8.3178RC，half-LSB需9.0109RC；不同误差口径不能套同一表。
模型或器件最低采样窗证据缺失返回`INSUFFICIENT_EVIDENCE`，不会升级为硬件精度通过。
输出是理想一阶下界；外储能电容的charge sharing、运放slew/recovery和频变输出阻抗不能
无依据并成单RC。该计算来自本地TI实时控制参考指南的RC表并经独立推导；数据手册/驱动模型更严格时优先。

`encoder.update_index` 选择本报告同一时基的更新预算；Park不可早于该次ADC读取或晚于装载，
apply不可早于该次ShadowLoad。不能通过填一组较早的孤立编码器时刻掩盖实际数据年龄。

## 单、双、三电阻采样约束

可选 `current_sampling` 由同一 `analyze` 执行，Schema给出字段；默认优先推荐PWM/定时器硬件
触发ADC，并在反馈支持时同步锁存/采集启动。软件触发需要独立的抖动/采样时戳证据。
选择 `single_dc_link`、`two_low_side`、`three_low_side` 或 `three_inline`，分别检查两有效矢量、
已安装两相的共同窗口、三相中任意两路有效窗口，或inline的共模恢复窗口。

窗口参照必须是**门极命令对应的实际连续开关区段**。本模型采用保守预算：
`settle=deadtime+driver_delay+rise_time+blanking+amplifier_settling`，
`required_window=settle+ADC_S/H+guard`。每项只计一次；若输入是已经测得的稳定窗口，
不要直接套本模型再重复扣除。公共传播延迟在真实有效矢量宽度定义中可能抵消，不能把本保守
command-referenced模型当成所有功率级的唯一精确公式。

`phase_windows_ns[3]`/`active_vector_windows_ns[2]` 是连续区段宽度，对应
`phase_sample_offsets_ns[3]`/`active_vector_sample_offsets_ns[2]` 是该区段起点到实际S/H开始的偏移。
仅窗口够宽不够：还要求 `offset>=settle`，`offset+S/H+guard<=window`。
`measured_phases` 用A=0/B=1/C=2声明实装通道；`switch_states` bit0/1/2代表A/B/C上管状态，
以 `idc=sA*ia+sB*ib+sC*ic` 和零和关系检查代数秩，拒绝零/相同/互补矢量。
时间差超过 `allowed_sample_skew_ns` 时拒绝按同刻电流重构；单电阻还需调用C99重构器，校验
有证据的电流斜率、样本年龄与误差界。程序不会自动移动PWM或修改任何保护参数。

## 输出、错误与证据

退出码：0 完成源码检查/条件计算；2 `INSUFFICIENT_EVIDENCE`；3 `CONSTRAINT_VIOLATION`；
4 `INVALID`、未知字段、缺少必需字段、数值/IO错误。程序只输出 JSON。
Schema命令给出结构；数值范围、枚举和跨字段约束由实际计算器验证，测试覆盖两者一致性。

没有执行捕获时 `wcet_status=NOT_MEASURED`。输入静态界限产生条件计算，不会升级为板测。
`observations` 只接收有来源的周期/GPIO捕获摘要，输出 `OBSERVED_MAX_ONLY`，有限样本最大值不
构成形式化WCET上界，也不能直接替换计算使用的界限。原始捕获真实性和探针扰动需人工核验。

已自动检查：Deadline、ADC未锁存/错拍、采样窗、采样策略、过期角度、重复预测、
捕获超界、未知执行/抖动、不合法数值、JSON字段及路径越界。未覆盖的硬件行为不得宣称通过。

## 测量接入

在现有获授权的工程中，用GPIO或周期计数器覆盖**ADC读取至最后一次Shadow写入**，同时捕获
SOC、ADC结果可读标记、PWM装载和编码器物理锁存。记录主频、优化等级、Flash/RAM路径、最坏
通信/DMA/CLA负载、嵌套中断、样本数及测量开销。去除/保留开销的选择要可追溯。
把同一范围的脉宽转换为 `durations_ns` 并保留原始捕获；检查最大值与设计界限、Deadline margin。
实机测试、Flash下载、功率级使能及运动注入不属于此CLI，也不由宿主测试授权。

执行成本用上面的 benchmark 实测。显式文件在单次检查中只读一次；当前不写持久解析缓存，
跨进程缓存和完整编译器语义适配仍为缺口。功能测试中的大量断言不能作为独立工况数或硬件覆盖率。
