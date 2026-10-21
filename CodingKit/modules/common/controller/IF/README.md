# I-f 开环电流控制器

本模块的核心目标是提供完整、可复用的 I-f 控制算法：**相电流输入 → 电流闭环 → 三相占空比输出，电角度由软件生成**。极对数识别、编码器方向与换相零位校准等能力，是使用 I-f 激励的上层应用。

本文记录设计合同、参考源码、阶段目的、实现和验收结果。S0/S1 文档、S2 共享基础与 S3 最小完整 IF 已完成；实际 C 与独立 R-L 闭环结果见第 6 节。S4 的运行边界验收、S5 的完整数值与示例验证、S6 的迁移交付仍待完成；尚无机械同步或实机性能证据。

## 1. 已确定的方向

| 决策 | 结论 | 状态 |
|---|---|---|
| 核心交付范围 | 完整 I-f 控制器，包含两轴电流调节及调制输出 | 已确认 |
| 数值基线 | 标准 C99、`float`，使用物理单位 | 已确认 |
| 与已有模块的关系 | 共享 PID、坐标变换和 SVPWM 等底层组件；IF 拥有独立对象与周期入口 | 已确认 |
| 应用边界 | 极对数识别、编码器校准及校准参数保存由上层拥有 | 已确认 |
| I-f 示例入口（Q6） | 新 IF 验证通过后，I-f 开环主示例统一使用 IF API；现有 FOC 对应能力保留兼容 | 已确认 |
| 三环示例归属（Q7） | 位置、速度、电流三环组合示例放在上层示例区；FOC、IF 各自展示本模块接口 | 已确认 |
| 平台范围 | 不安排具体 MCU、SDK、板卡或多个平台的移植阶段；只定义通用数据契约 | 已确认 |
| S1 基线 | 三个接口、物理单位、离散时序、矢量限幅、最终输出回算及启停恢复合同 | S1 已固定，见第 4、5、9 节 |
| S2 共享基础 | 共享链接目标、PID 最终输出跟踪、SVPWM 归一化验证与六示例基线 | 已完成，见第 6 节 |
| S3 最小完整链路 | 独立 IF 对象、软件角度、两轴 PI、矢量限压与 SVPWM，实际 C 与 R-L 测试 | 已完成，见第 6.3 节 |
| 当前工作范围 | 完成 S3；运行行为的系统验收、完整长时间矩阵和示例迁移继续按阶段推进 | 已确认 |

算法与应用的划分以职责决定，不以芯片型号划分。

## 2. 当前仓库基础

IF 目录在本计划建立前为空；相邻模块已经提供一部分可复用能力：

| 现有资产 | 已有事实 | 对本计划的意义 |
|---|---|---|
| [FOC 控制器](../foc/README.md) | `FOC_MODE_IF` 与 `FOC_ANGLE_OPEN_LOOP` 可组合为开环角度下的电流控制 | 用作现有行为基线，不整体包装其包含位置环、速度环的 `Foc` 对象 |
| [FOC 主链路](../foc/src/foc.c) | 已有电流校正、Clarke/Park、两轴调节、电压限幅、逆 Park 和调制调用 | 识别共同原语与待复核约定，避免复制整段实现 |
| [坐标变换](../foc/src/foc_math.h) | 提供独立的 abc、alpha-beta、dq 变换和数学函数 | 复用同一份数学实现 |
| [SVPWM](../foc/src/foc_svpwm.h) | 已有独立调制对象和占空比计算入口 | 复用调制算法，先核对其归一化定义 |
| [PID](../pid/README.md) | 通用 C99、`float`，包含积分抗饱和 | 以 PI 配置复用，不在 IF 中重写 PID 公式 |
| [现有开环电流示例](../foc/examples/open_loop_current_example.c) | 已有软件电频率与电流给定的调用示例 | 用于对照输入输出，不将示例数值当作通用电机参数 |
| [模块设计原则](../../../DESIGN.md) | 要求平台无关、静态分配、可独立测试和易用 | 采用显式数据输入输出；通信模块的回调、变参和串口处理方式不机械套用到控制周期 |

这里的 `FOC_MODE_IF` 是现有源码对电流链路的命名；只有它与开环角度来源组合时，才对应本文的 I-f。S2 建立旧路径基线，S3 增加独立 `if_controller`；两者都只有第 6 节记录的宿主证据，尚无实机验证。

## 3. 职责与依赖

| 层次 | 拥有的职责 | 输入与输出 |
|---|---|---|
| IF 核心 | 软件电角度、频率与电流参考整形、两轴电流闭环、电压约束、调制、算法状态 | 相电流、母线电压、运行命令 → duty 与观测量 |
| 共享基础组件 | 坐标变换、PI/PID、调制数学 | 纯数值输入 → 纯数值输出 |
| 上层应用 | 极对数识别、编码器标定、测试步骤、成功判定、结果保存 | 调用 IF 生成激励，结合外部观测计算应用结果 |
| 工程接入 | 采样、定周期调用、占空比应用、硬件使能与停机 | 把实际设备数据映射到统一契约 |

依赖方向为：

```text
上层应用 / 工程组合
        ↓
独立 IF 控制器
        ↓
共享 PI/PID、变换、调制数学
        ↓
标准 C 运行库
```

IF 核心不需要编码器、极对数、机械转速、减速比或校准结果。它接受电气频率；机械速度到电气频率的换算由调用方完成。

位置环、速度环、观测器、编码器驱动、通信、参数存储、抱闸和完整设备故障状态机不进入 IF 对象。IF 可以报告算法输入无效或输出受限；实际硬件保护与执行权仍由接入工程拥有。

## 4. S1：数学与离散控制合同

本节与第 5、9 节是 S1 的确定合同，实现与测试以此为准；已验证范围单列在第 6 节，不因存在合同就推定全部完成。

### 4.1 单位、相序与坐标系

| 量 | 确定约定 |
|---|---|
| 控制周期 `Ts` | s；固定周期，唯一时间基准，不由函数调用耗时推导 |
| 三相电流 | A，正方向为逆变器流向绕组；输入顺序固定为 a、b、c |
| d/q 电流 | A，幅值不变变换下的相电流峰值；不使用 RMS 或标幺值 |
| 母线、相电压、d/q 电压 | V；相电压指去掉共模后的相对电机中性点电压 |
| 电频率 `f` | 带符号的电气 Hz，正负号是唯一方向来源 |
| 相位、单周期相位增量 | rad；使用相位属于 `[0, 2*pi)`，增量保留正负号 |
| 电流、频率变化率 | A/s、Hz/s，均为正的幅值上限 |
| duty | 无单位，a、b、c 上桥臂导通占比，范围由 `dutyMargin` 约束 |

输入必须已经完成采样比例换算和 offset 校正；两电阻采样的第三相重建在调用前完成。核心先去掉三相均值，再使用现有简化 Clarke，等价于下列完整的幅值不变变换；这一步是零序投影，不是 offset 校准：

```text
i0 = (ia + ib + ic) / 3
i_alpha = ia - i0
i_beta  = (ib - ic) / sqrt(3)

id =  cos(theta) * i_alpha + sin(theta) * i_beta
iq = -sin(theta) * i_alpha + cos(theta) * i_beta

v_alpha = cos(theta) * vd - sin(theta) * vq
v_beta  = sin(theta) * vd + cos(theta) * vq

va = v_alpha
vb = -v_alpha / 2 + sqrt(3) * v_beta / 2
vc = -v_alpha / 2 - sqrt(3) * v_beta / 2
```

正序定义为 `ia = I*cos(theta)`、`ib = I*cos(theta - 2*pi/3)`、`ic = I*cos(theta + 2*pi/3)`，对应 `id = I, iq = 0`。正 q 轴相对正 d 轴超前 `pi/2`。这些 dq 轴由软件生成，不预设已经与真实转子 dq 轴对齐。

固定方向校准统一推荐 `id_target = I_cal, iq_target = 0, f_target = 0`；q 轴激励的应用自行换算 90° 电角度偏移。电流跟踪与真实转子同步是分别需要观察的结果。

### 4.2 电流、频率与相位轨迹

所有目标先限幅、再限速。设 `clip_norm(x, L)` 表示将矢量径向缩放到半径 L 的圆盘内，圆盘内保持原值；零矢量不做除法。

```text
i_target_limited = clip_norm([id_target, iq_target], currentLimitA)
di = i_target_limited - i_ref_previous
i_ref = i_ref_previous + clip_norm(di, currentSlewAps * Ts)

f_target_limited = clamp(f_target, -frequencyLimitHz, frequencyLimitHz)
f_goal = 0                         if f_previous and f_target_limited have opposite signs
         f_target_limited          otherwise
f_ref = move_toward(f_previous, f_goal, frequencySlewHzps * Ts)
```

电流限速约束的是两轴合成变化量，不能将两轴各自允许的变化率相加；斜坡后的参考仍位于电流圆盘内。频率反向时先精确到零，本周期不得越过零；下一周期才向反向目标推进。改变频率符号不自动翻转 d/q 电流符号。

`START` 时两项参考从零起步。零频率表示固定方向激励；零电流目标也不自动停止控制器，电流 PI 仍可调节反馈。只通过状态命令退出运行。

```text
delta_theta[k] = 2 * pi * f_ref[k] * Ts
theta_next = wrap(theta_used[k] + delta_theta[k])
```

Park、逆 Park 以及输出电压重建使用同一份 `theta_used[k]`。`START` 首周期先使用指定初相位，周期末才推进到下一相位。运行中不直接重置相位；固定相位之间的移动通过频率轨迹完成，或停止后重新启动。

相位保持有界，并保留有界的加法误差补偿或具有同等精度的状态，避免低频增量被浮点舍入长期吞掉。不在单个 `float` 中无限累计总角度；应用所需多圈角度由应用根据有效周期的增量自行展开。

### 4.3 两轴 PI 与最终输出抗饱和

第一版使用 PI，不启用微分、前馈、电机参数解耦、死区或共享 PID 内部的第二套参考斜坡。共享 PID 的参考/反馈/误差限幅与单轴输出限幅在 IF 路径关闭，仅使用本合同的参考整形、积分状态限幅和电压矢量限幅。d/q 两轴均闭环，分别使用各自增益。令 `J` 为单位 V 的积分状态：

```text
e_d[k] = id_ref[k] - id_feedback[k]
e_q[k] = iq_ref[k] - iq_feedback[k]
vd_raw[k] = kp_d * e_d[k] + J_d[k]
vq_raw[k] = kp_q * e_q[k] + J_q[k]

J_axis[k+1] = clamp(
    J_axis[k] + ki_axis * Ts *
        (e_axis[k] + kaw_axis * (v_axis_applied[k] - v_axis_raw[k])),
    -integralLimitV_axis, integralLimitV_axis)
```

`kp` 单位为 V/A，`ki` 为 V/(A*s)，`kaw` 为 A/V。因此 `ki*kaw` 才是回算的每秒增益，不能把单位为 1/s 的数直接填进 `kaw`。每周期先以旧积分计算原始电压，调制后再更新一次积分；`ki = 0` 时积分始终为零。

`v_applied` 必须从本周期最终 duty 与同一母线电压重建，再按同一相位转回 dq。它覆盖电压矢量缩放和最终舍入处理，不能只回传单轴 PI 自身的限幅结果。禁止先调用会更新积分的旧入口，再直接修改其私有积分补一次回算。

S2 已通过 `pid_eval()`、`PidStep` 与 `pid_track()` 补齐“评估原始输出 → 使用最终施加输出更新积分”的公开两阶段能力，并验证已有 `pid()` 行为兼容，见第 6.1 节。S3 的 IF 通过该能力复用 PI，不另写一套 PI，也不越界操作 PID 内部字段。

### 4.4 电压约束与 SVPWM

配置 `eta = dutyMargin`，满足 `0 <= eta < 0.5`。第一版只使用圆形线性电压区，不启用过调制：

```text
V_limit[k] = min(voltageLimitV, (1 - 2*eta) * Vbus[k] / sqrt(3))
[vd_limited, vq_limited] = clip_norm([vd_raw, vq_raw], V_limit[k])
[v_alpha, v_beta] = inverse_park(vd_limited, vq_limited, theta_used)

[v_a, v_b, v_c] = inverse_clarke(v_alpha, v_beta)
v_common = -(max(v_a, v_b, v_c) + min(v_a, v_b, v_c)) / 2
duty_x = 0.5 + (v_x + v_common) / Vbus
```

共享 SVPWM 的输入归一化固定为 `[v_alpha, v_beta] / Vbus`；其 IF 实例的最大调制幅值必须显式设置为 `V_limit / Vbus`，不照搬现有默认 `sqrt(3)/2`。在上述归一化下，零裕量时的圆形线性上限是 `1/sqrt(3)`。S2 已验证这一差异，S3 的 IF 已显式配置并检查最终 duty；原 FOC 的默认值和行为保持不变。

最终 duty 应在 `[eta, 1-eta]` 内。仅允许第 9 节容差内的舍入修正；明显越界、非有限输出或非舍入引起的额外调制失真都进入算法故障，不能依靠逐相硬裁剪后继续报告正常。底层 `valid` 或边界 `saturated` 标记不能代替此检查。

用最终 duty 重建实际平均施加电压：

```text
d_mean = (duty_a + duty_b + duty_c) / 3
v_x_applied = Vbus * (duty_x - d_mean)
[v_alpha_applied, v_beta_applied] = clarke(v_a_applied, v_b_applied, v_c_applied)
[vd_applied, vq_applied] = park(v_alpha_applied, v_beta_applied, theta_used)
```

这里的“施加”是按理想逆变器模型由输出 duty 计算的平均电压，不含开关死区、器件压降或硬件执行确认。

### 4.5 单周期的固定顺序

一次成功且输出有效的 `if_update()` 对应一个周期 k，顺序固定为：

1. 读取一次完整输入快照；处理状态命令，校验本周期实际使用的数据。
2. 如为启动，清零 PI 与轨迹状态，装载初相位；否则延续上周期状态。
3. 对目标限幅、执行参考斜坡，得到本周期 `i_ref[k]`、`f_ref[k]`；正常停机改用第 5.5 节的轨迹。
4. 取得 `theta_used[k]`，将已校正的电流去零序并做 Clarke/Park。
5. 以 `J[k]` 计算两轴原始电压，径向限压、逆 Park、SVPWM，检查并修正允许的舍入误差。
6. 从最终 duty 重建 dq 电压，完成一次 PI 回算，得到 `J[k+1]`。
7. 计算 `delta_theta[k]` 与下一相位；所有中间量有效后保存下一周期状态，最后将 `outputValid` 置为 true。

输出中的角度是本周期使用角度，积分观测是更新后的 `J[k+1]`。停止、故障及失败调用不执行相位推进，也不保留一个半更新的正常运行状态。

输入电流属于调用方本次采样，返回 duty 用于随后的执行区间。核心不读取时钟、不推测漏周期，也不暗中补偿采样/PWM 延迟。应用必须将编码器观测与当时实际施加的激励关联，不能把新输出与此前采样当作同时发生。

## 5. S1：接口与生命周期合同

### 5.1 三个公开入口与对象所有权

S1 固定以下接口形状；S3 已在[公共头](src/if_controller.h)和[实现](src/if_controller.c)中交付：

```c
IfStatus if_init(IfController *controller, const IfConfig *config);
IfStatus if_reset(IfController *controller);
IfStatus if_update(IfController *controller,
                   const IfInput *input,
                   IfOutput *output);
```

`IfController` 为调用方持有的完整可静态分配类型，首次使用前以 `{0}` 初始化，此时为 `IF_STATE_UNINITIALIZED = 0`。内部保存独立配置、PI、参考轨迹和相位状态；调用方不直接改写内部成员，不在运行中复制对象。一个实例只有一个执行者，多实例互不共享可变状态。

| 入口 | 确定行为 |
|---|---|
| `if_init` | 仅在 UNINITIALIZED、STOPPED、FAULT 调用；完整校验后复制配置并清运行状态，成功进入 STOPPED。失败保留调用前对象，不偷偷应用部分配置 |
| `if_reset` | 仅在已成功初始化的 STOPPED、FAULT 调用；保留配置，清故障、参考、积分、相位及补偿，进入 STOPPED；不会自动启动 |
| `if_update` | 每个固定周期恰好一次；输入只读，输出每次完整覆盖，状态跨周期保存；不包含隐式初始化 |

在 RUNNING、STOPPING 调用初始化或复位返回 `IF_ERR_STATE`，对象不变；修改周期、增益和限值须先停止，再重新初始化。首次 `if_init` 失败后不能靠 `if_reset` 获得有效配置。

对象、输入、输出的存储不得重叠；调用期间输入不能被其他执行者改写。核心无堆分配、I/O、延时、系统时钟或动态后端框架。初始化/复位由调用方在执行器已禁用时组织；旧输出只对产生它的那个调用周期有效。

### 5.2 配置：IfConfig

字段名与单位在本阶段固定；`piD`、`piQ` 使用同一 `IfPiConfig` 字段集，其余配置保持一层。除枚举、bool、`uint32_t flags` 与对象成员外，下列配置、输入、输出数值字段均使用 `float`：

| 字段 | 单位 | 有效范围与语义 |
|---|---|---|
| `periodS` | s | 有限且 > 0；内部 PI 频率仅由其倒数推导，且满足共享 PID 的 `controlFreq > PID_EPSILON` 有效范围 |
| `currentLimitA` | A | 有限且 > 0；合成 d/q 电流参考幅值上限 |
| `frequencyLimitHz` | 电气 Hz | 有限且 > 0；目标的对称幅值上限，且 `frequencyLimitHz*periodS < 0.5` |
| `currentSlewAps` | A/s | 有限且 > 0；合成电流参考变化率，零不表示关闭限速 |
| `frequencySlewHzps` | Hz/s | 有限且 > 0；频率参考变化率，零不表示瞬时跳变 |
| `voltageLimitV` | V | 有限且 > 0；用户电压矢量上限，零不表示无限制 |
| `busMinV` | V | 有限且 > 0；运行时要求 `Vbus >= busMinV` |
| `dutyMargin` | 无单位 | 有限，`0 <= eta < 0.5`；同时决定电压圆盘和 duty 两端裕量 |
| `piD.kp`、`piQ.kp` | V/A | 有限且 > 0 |
| `piD.ki`、`piQ.ki` | V/(A*s) | 有限且 >= 0；零表示该轴 P 控制 |
| `piD.kaw`、`piQ.kaw` | A/V | 有限且 >= 0；`ki > 0` 时要求 `kaw > 0` 且 `0 < ki*kaw*periodS <= 1` |
| `piD.integralLimitV`、`piQ.integralLimitV` | V | 有限且 `0 < limit <= voltageLimitV`；对积分状态施加对称约束 |

初始化还须拒绝倒数或上述乘积溢出、正量下溢为零，以及无法在配置最大参考附近推进斜坡的配置。具体可判定条件为：令 `step = slew*periodS`，在 `float` 运算下，频率和电流分别满足 `limit - min(step, limit) < limit`。运行中的大数范数与投影也不得先溢出再假装限幅成功。

数值基线为至少具有二进制 24 位有效精度与 binary32 指数范围的 `float`；不以 `sizeof(float) == 4` 推断精度。构建选项必须保留合同要求的非有限数检查语义。电机、采样范围、增益及激励限值由使用方显式提供，不设置一个默认即可带任意电机运行的参数组。参考电流限值不是反馈过流判据。

### 5.3 输入：IfInput

| 字段 | 类型/单位 | 确定语义 |
|---|---|---|
| `action` | `IfAction` | `IF_ACTION_KEEP = 0`、`IF_ACTION_START`、`IF_ACTION_STOP`、`IF_ACTION_DISABLE`；零初始化输入不请求启动 |
| `sampleValid` | bool | 当前电流与母线快照完整且有效；运行和停机轨迹中必须为 true |
| `phaseCurrentA[3]` | A | 已校正的 a、b、c 三相电流 |
| `busVoltageV` | V | 与本次计算配对的母线电压 |
| `frequencyTargetHz` | 电气 Hz | 运行目标，幅值越限时限幅并报告，不作为故障 |
| `currentTargetDqA[2]` | A | 运行目标，按 d、q 顺序，合成幅值越限时限幅并报告 |
| `startAngleRad` | rad | 仅 STOPPED + START 消费；有限且属于 `[0, 2*pi)`，调用前完成角度归一化 |

`KEEP` 只保持运行状态，目标仍每周期更新；`START` 在 RUNNING 中等同 KEEP，不重复清积分或重置相位。`STOP` 是锁存的受控停止请求。`DISABLE` 是立即令输出失效的请求，不等待斜坡。

STOPPED 中未 START 时不消费数值输入；STOPPING 忽略外部目标和初相位，只消费采样；RUNNING 忽略初相位。被忽略字段不参与非有限数校验。DISABLE 优先于采样校验，即使采样已经无效，也能立即退出有效输出。

### 5.4 输出：IfOutput

| 字段 | 确定语义 |
|---|---|
| `state`、`status` | 本次调用结束的 `IfState` 与 `IfStatus`，正常停止可返回 IF_OK |
| `outputValid`、`duty[3]` | 是否要求调用方应用本周期 a、b、c duty；只有 valid 为 true 才可使用 |
| `flags` | 本周期数值限制标记，每次重算，不锁存成设备故障 |
| `currentRefDqA[2]`、`currentFeedbackDqA[2]` | 本周期整形后的参考与 dq 反馈，单位 A |
| `frequencyRefHz` | 本周期实际推进相位所用的电频率 |
| `thetaUsedRad`、`deltaThetaRad` | 本周期变换角度、周期末推进量，单位 rad |
| `voltageRawDqV[2]`、`voltageAppliedDqV[2]` | PI 原始电压、最终 duty 重建电压，单位 V |
| `voltageLimitV`、`integralDqV[2]` | 本周期电压上限、回算后的积分状态，单位 V |

`flags` 为 `uint32_t` 位掩码，按 bit0～bit5 固定为 `IF_FLAG_CURRENT_LIMITED`、`IF_FLAG_FREQUENCY_LIMITED`、`IF_FLAG_CURRENT_SLEW`、`IF_FLAG_FREQUENCY_SLEW`、`IF_FLAG_VOLTAGE_LIMITED` 和 `IF_FLAG_DUTY_ROUNDOFF`。前两项表示外部目标越限，中间两项表示参考尚未到达限幅后的目标（包括频率反向时的零点），后两项分别表示电压矢量缩放与允许的 duty 舍入修正；其他位为零。

任何无效输出都保留 state/status，清 flags，并将其余数值字段包括 duty 置零；不返回上一周期的有效数据。调用方每周期同时检查返回状态与 `outputValid`：无效时执行禁用动作，有效时才应用新 duty。`duty = 0` 或 `0.5` 本身均不表示硬件 PWM 已关闭，`outputValid = true` 也不证明硬件实际执行成功。

### 5.5 状态、启动与停止

`IfState` 固定为 `IF_STATE_UNINITIALIZED`、`IF_STATE_STOPPED`、`IF_STATE_RUNNING`、`IF_STATE_STOPPING`、`IF_STATE_FAULT`：

| 当前状态 | 请求或条件 | 结果 |
|---|---|---|
| UNINITIALIZED | init 成功 | STOPPED，参考/积分/相位清零，无有效输出 |
| STOPPED | KEEP、STOP、DISABLE | 保持 STOPPED，无有效输出，不检查未消费的采样 |
| STOPPED | START 且本周期数据有效 | RUNNING，从零参考、零积分与指定初相位执行首周期 |
| RUNNING | KEEP、START | 延续相位和积分，处理新目标 |
| RUNNING | STOP | 进入 STOPPING，锁存当前参考，按下述两段轨迹停止 |
| RUNNING、STOPPING | DISABLE | 当次即 STOPPED，清参考和积分，不推进相位，无有效输出 |
| STOPPING | KEEP、START、STOP | 继续原停止轨迹，不取消停止，不排队重启 |
| STOPPING | 两段参考轨迹均到零 | 当次即 STOPPED，清积分，无有效输出，不再多输出一个激励周期 |
| 已初始化状态 | 被消费输入或计算失败 | FAULT，清参考和积分，当次输出失效 |
| FAULT | 任意 update 命令 | 保持 FAULT、返回锁存故障；DISABLE 也不清故障 |
| STOPPED、FAULT | reset 成功 | STOPPED；后续必须再 START 才能运行 |

START、STOP 是本次调用的请求，不缓存未被接受的启动。STOPPING 中的 START 不会在完成时自动执行；应用收到 STOPPED 后按需要重新发送 START。正常停机按进入时的参考执行：

1. 冻结当前 d/q 电流参考，按频率斜率将参考电频率降到零，不越过零。
2. 频率已经为零后的下一周期开始，按电流矢量斜率将参考电流降到零；若入停机时频率已为零，则立即执行这一步。
3. 两项参考都到零的那个调用，直接清积分并发布 STOPPED/无效输出；前面仍在斜坡内的周期继续执行完整电流闭环。

参考轨迹的理想持续时间为 `abs(f_entry)/frequencySlewHzps + norm(i_entry)/currentSlewAps`，离散剩余步长裁剪到目标，数值行为按第 9 节验收。这里完成的是参考停机，真实机械静止、制动或失步判断属于上层应用。立即禁用和故障均不等待这个轨迹；之后的 START 重新装载初相位，不沿用停机前积分。

### 5.6 状态码、校验顺序与恢复

| IfStatus | 触发与处理 |
|---|---|
| `IF_OK = 0` | 调用正常完成；是否输出激励另看 `outputValid` |
| `IF_ERR_NULL` | 任一必需指针为 NULL；不修改控制器，若 output 可写则写完整无效输出 |
| `IF_ERR_CONFIG` | init 配置范围或关联约束不满足；对象不变 |
| `IF_ERR_STATE` | 未初始化就 update/reset，或活动状态 init/reset；不改变已有控制状态 |
| `IF_ERR_ACTION` | 已初始化对象收到枚举范围外的 action；锁存 FAULT |
| `IF_ERR_SAMPLE` | 活动周期 `sampleValid = false`；锁存 FAULT |
| `IF_ERR_NUMBER` | 被消费数值是 NaN/Inf；锁存 FAULT |
| `IF_ERR_RANGE` | 启动初相位有限但不在约定范围内；锁存 FAULT |
| `IF_ERR_VBUS` | 活动周期母线有限但小于 `busMinV`；锁存 FAULT |
| `IF_ERR_CALC` | 中间计算非有限、共享算法失败或超容差的输出越界；锁存 FAULT |

update 优先级固定为：指针与对象生命周期检查 → 已锁存故障 → action 合法性 → DISABLE → 不活动状态分支 → sampleValid → 被消费数值有限性 → 母线范围 → 启动初相位范围 → 数值计算。首次故障码锁存，后续 update 不用另一错误覆盖它；FAULT 中的 DISABLE 保持无效并返回原故障。controller 为 NULL 而 output 可写时，输出 state 取 UNINITIALIZED；output 为 NULL 时仅返回状态码，对象不变。

无效输入不退回电压开环，也不复用旧 duty。恢复流程是上层处理原因、调用 reset、确认 STOPPED，再显式 START；更换配置时可以重新 init 后再 START，不能仅凭下一帧恢复正常就自动恢复运行。

## 6. 与现有 FOC/PID 的共享方案

已确认采用“共享底层组件、IF 独立”的方式：

1. 先核对现有变换、调制及 PID 的定义和测试，建立行为基线。
2. 将必要的数学与 PID 构建依赖整理为可独立链接的目标，FOC 与 IF 共同使用唯一源码。
3. IF 不包含整个 `Foc` 对象，不携带其位置/速度环或 VF 模式字段。
4. S2 已补齐第 4.3 节要求的通用 PID 两阶段评估/最终输出跟踪能力，并回归原有 PID/FOC；旧 `pid()` 的数学处理与完成后的行为保持兼容，IF 不直接越界修改 PID 私有状态。
5. S2 显式核对 `v_alpha_beta / Vbus` 的 SVPWM 归一化，为 IF 设置不超过 `1/sqrt(3)` 的圆形线性上限，并验证 duty 重建电压与回算一致；不在无基线时整体替换原 FOC 调制语义。
6. 保留现有 FOC 的公开入口及已确认行为；共享调整与 IF 新功能分阶段验证，避免无法判断回归来自哪一步。

共享组件保留现有源码目录，S2 仅拆分构建依赖并扩展通用 PID，具体落位如下。后续只有真实依赖变化要求独立组织时才移动文件，不为目录对称增加框架。

### 6.1 S2 已交付的共享构建与 PID 接口

[共享构建入口](../cmake/ControllerPrimitives.cmake)提供以下目标，源码仍在原目录，没有复制算法或移动公共头：

| 目标 | 唯一实现来源 | 使用关系 |
|---|---|---|
| `pid_controller` | `pid/src/pid.c` | 常规 PID、FOC 与 IF 共用 |
| `controller_math` | `foc/src/foc_math.c` | 坐标变换与基础数学 |
| `controller_svpwm` | `foc/src/foc_svpwm.c` | 只依赖共享数学 |
| `controller_primitives` | INTERFACE 目标，无第二份算法源码 | 汇合以上三个目标，FOC 与 IF 直接链接它 |
| `foc_controller` | `foc/src/foc.c` | PUBLIC 链接共享目标；原目标名和调用入口保持可用 |

[controller 构建入口](../CMakeLists.txt)、原 PID 目录和原 FOC 目录均可独立配置。FOC 不再把 PID 源码重复编入自己的目标，原来通过 CMake 链接 `foc_controller` 的调用方自动获得传递依赖；手动收集静态库时需同时收集 PID、数学和调制库，不能只复制单个 FOC archive。

通用 PID 已新增 `PidStep`、`pid_eval(const Pid *, PidStep *)` 和 `pid_track(Pid *, float appliedOutput, PidStep *)`。原 `PidLimit/PidInput/PidConfig/PidState/Pid` 的成员顺序和类型不变，原 `pid_init()`、`pid()` 与既有状态码数值保持兼容；新增 `PID_ERR_NUMBER`、`PID_ERR_STEP` 只服务新路径。

- `pid_eval()` 不修改原实例和积分；成功后读取 `step.next.rawOutput`，`step.next.output` 仅表示已有单轴限幅输出。
- 调用方完成最终矢量限幅及 duty 电压重建，再对每轴调用一次 `pid_track()`。它仅用最终施加值回算，不重复裁剪最终输出。
- 候选由调用方持有，可直接丢弃；同一实例只允许一个活动候选。评估至跟踪期间不改动实例，不混入旧入口调用，也不复制活动候选。快照/归属检查拒绝交错修改与跨实例误用，每次跟踪尝试后候选失效。
- 新路径失败时原实例连同 `state.status` 不变，必须检查返回状态；旧 `pid()` 保持原来的非法配置处理，不偷偷收紧旧调用方的数值契约。

共享 SVPWM 的原函数、默认 `sqrt(3)/2` 和 FOC 调用行为均未改动。实际 C 测试已验证第 4.4 节的 `v_alpha_beta/Vbus` 归一化以及 `(1-2*eta)/sqrt(3)` 圆形线性上限；也固定了旧默认值可能逐相裁剪而仍返回 valid 的现状。S3 的 IF 已显式配置自己的实例，并检查缩放、理想中心化 duty 与最终 duty，不以旧默认值证明线性调制成立。

### 6.2 S2 基线与实际验证结果

[原始基线及来源](../tests/fixtures/README.md)记录修改前源码 SHA-256、采集提交、编译条件及固定结果；参考来自修改前实际 C 执行，不是 Python 重写公式。[实际 C 测试](../tests/CMakeLists.txt)现已接入 CTest：

| 验证项 | 本阶段结果与边界 |
|---|---|
| 旧入口状态基线 | 72 条 PID、55 条 FOC 记录通过；覆盖 P/PI/PD/PID、限幅、微分、斜坡、offset、模式、非法配置及恢复；PID 各状态字段均比较 |
| PID 新路径 | 3,000 周期与旧入口成功路径等价；另验单次最终输出回算、积分裁剪顺序、持续外部饱和及退出、空指针、非有限数、溢出和候选误用 |
| 坐标变换 | 720 个角度对独立双精度公式，固定幅值和正负号 |
| SVPWM | 64,800 组母线/裕量/用户限压/幅值/角度组合；覆盖所有扇区、边界与自动缩放，检查最终 duty 与独立重建电压 |
| S1 V06～V08 | V06/V07 确定 duty，72 个角度下经真实最终 duty 重建完成 V08 两轴积分回算 |
| 六个现有示例 | 六个独立宿主目标均编译、链接并执行；每个入口重复两次，确认其当前每次初始化、每次只跑一个周期的事实，未将其记为持续调用合格 |
| 构建与兼容 | controller Debug 10/10、FOC 独立 Release 10/10、PID 独立 Release 1/1；Release 全目标使用 `-Wall -Wextra -Werror -pedantic`；五个旧 PID 结构的类型/成员顺序相同，12 个 FOC 源码/示例 SHA-256 未变 |
| 原有验证 | PID 的 24 项 Python 测试、FOC 的 11 项模型检查、原静态检查与编码检查通过；它们作为补充，不代替实际 C 测试 |

以上是 S2 的历史基线；S3 的独立 IF 和 R-L 结果见下一节。共享链路验证与完整 IF 入口验证分别记录。

### 6.3 S3 已交付的独立 IF 与闭环证据

[IF 构建入口](CMakeLists.txt)提供 `if_controller`，PUBLIC 链接 `controller_primitives`。独立构建只编译 IF、PID、数学和 SVPWM 四份生产源码，不编译或包含 `foc.c`，不持有 `Foc`、位置环、速度环或设备对象。[控制实现](src/if_controller.c)通过共享 `pid_eval()` / `pid_track()` 各执行一次两轴评估与最终输出跟踪，没有复制 PI 公式。

为使 S1 的完整入口可用，S3 同时接入了合同要求的参考整形、过零、启停和故障处理。每次在局部候选对象中计算，候选的 PID 地址在评估到跟踪间保持不变；两个轴、调制及相位均成功后才发布。失败清参考和积分、冻结原相位并锁存首次故障，输出完整清零。PID、候选和输出使用有界自动存储，不分配堆；目标上的栈占用和周期耗时尚未测量。

内部范数、参考差及三相零序投影先缩放再运算；相位使用有界 `float` 与加法误差补偿，不无限累计总角度。新 IF 文件为 UTF-8 无 BOM、LF；原 PID/FOC 编码和源码保持 S2 状态。编译时检查 `float` 精度与指数范围，并拒绝可识别的 fast-math/finite-math-only 模式；其他编译器也必须保留非有限数检查语义。

| 实际 C 验证 | 结果与范围 |
|---|---|
| [完整入口测试](tests/test_if_control.c) | V01～V12 的确定算例通过：去零序与 dq 正号、欧氏电流斜坡、首拍角度、频率过零、V06/V07 duty、V08 最终输出回算、停机终点、保持、禁用、故障锁存和配置原子性；另测两轴不同增益、NULL、Inf/NaN、大有限目标及第二轴回算失败 |
| 完整 IF 调制扫描 | 12,960 组：3 母线 × 3 裕量 × 4 电流向量 × 360 角度；由独立 double 公式核对最终 duty、电压圆盘与施加电压，全扇区通过 |
| 基础相位累计 | 5 组频率 `0, +/-0.0001, +/-10 Hz` 各 100,000 周期，含负微小增量与环绕；最大圆周误差约 `3.47e-5 rad`，零频不漂移、低频有累计推进。这不是第 9.2 节完整百万周期矩阵验收 |
| [独立 R-L 闭环](tests/test_if_rl.c) | 第 9.3 节参数；初角 0、pi/3 下分别测试 d/q 1 A 激励，四组峰值均 <= `1.00012 A`，正常及降母线后的稳态最大误差 <= `3.12e-5 A`，交叉轴与全部 duty 满足合同 |
| 饱和与恢复 | 同四组激励，0.5 V 限压持续 100 ms，电流达到 `0.5 +/-0.02 A` 且持续标记限压、积分不越界；撤销目标 50 ms 后两轴均 <= `0.02 A`；V08 独立确认最终电压回算，不仅依赖积分硬限幅 |
| 构建与兼容 | GCC 14.2.0，C99，`-Wall -Wextra -Werror -pedantic`；controller Debug/Release 均 12/12 CTest，独立 IF Release 3/3；S2 的旧状态固定参考、共享数值测试和六个示例宿主全部通过；原 PID/FOC 源码、接口与原示例未改 |

模型从最终 duty 和输入母线独立生成施加电压与下一拍电流，不调用生产坐标变换，也不把控制器电压观测直接作为模型输入。这些结果证明宿主上的电气链路；S4 的系统运行边界、多实例隔离、S5 的完整长时间矩阵和持续调用示例仍待验收。既有六个示例继续原位保留，尚未迁移。

## 7. 分阶段实施计划

S0/S1 文档、S2 共享基础与 S3 最小完整 IF 已完成，第 6 节列出交付证据。S4～S9 尚未完成；S3 为遵守入口合同已接入基础运行行为，S4 继续完善并系统验收，S5/S6 再完成长期矩阵、持续调用示例和迁移。上层应用可以在 IF 核心完成后单独立项，不阻塞核心交付。

| 阶段 | 目的 | 主要产物 | 完成判据 | 依赖 |
|---|---|---|---|---|
| S0：范围与计划 | 统一“IF 是核心、校准是应用”的认识 | 本 README、已确认决策与设计树 | 计划可审查，阶段目的和边界完整 | 无 |
| S1：数学与行为合同 | 消除单位、坐标、采样时序、启停与示例生命周期歧义 | 第 4、5、9 节合同、V01～V12 与模型指标，文档已完成 | 接口字段、单周期顺序、限幅回算和状态迁移可独立验算 | S0 |
| S2：共享基础（已完成） | 为 IF 提供唯一基础，并建立现有示例的迁移基线 | 共享构建目标、PID 两阶段跟踪、SVPWM 数值验证与六示例宿主基线 | 第 6 节结果通过，原 FOC/PID 接口与行为兼容；无示例源码迁移 | S1 |
| S3：最小完整 IF（已完成） | 打通相电流到 duty 的真实控制闭环 | 独立对象、固定方向激励、软件角度、两轴 PI、限压和调制 | 第 6.3 节实际 C 与 R-L 基准通过，原 FOC/PID 兼容 | S2 |
| S4：完整运行行为 | 让核心可用于连续运行和可控实验 | 斜坡、正反转、保持、启停、复位、有效性状态 | 边界、异常恢复、多实例及连续性测试通过 | S3 |
| S5：数值与闭环验证 | 证明算法行为，并验证示例的实际构建与持续调用 | 实际 C 测试、独立基准、闭环结果、示例编译链接和多周期验证 | 满足 S1 指标，示例状态持续且输出有效性处理正确 | S4 |
| S6：易用交付与示例收敛 | 交付独立 IF，并完成现有示例整理和迁移 | IF 主示例、FOC 基础示例、上层三环示例、去重及引用更新 | 替代示例先通过验证，再切换入口；无重复主示例、失效引用或构建缺口 | S5 |
| S7：极对数识别应用 | 用 IF 激励与外部位置观测估计机械/电气比例 | 独立应用流程、结果质量与拒绝条件 | 正反向、多次识别一致；不把失败结果写成有效参数 | S6 |
| S8：编码器换相校准应用 | 识别方向与电角度偏置 | 独立扫描与求解流程、质量报告 | 正反扫描、圆周统计、重复性和结果使用验证通过 | S6；需要已知或可靠的极对数 |
| S9：按需扩展应用 | 支持更具体的标定和启动用例 | 独立扩展规格及对应验证 | 每个扩展有实际需求和独立验收，IF 核心职责不扩大 | S6；依具体应用而定 |

### S0：范围与计划

**目的：** 先确定实现什么、复用什么、应用放在哪里，避免边写代码边改变边界。

本阶段只形成可审查的计划。完整 IF、`float` 物理单位、底层共享和应用分层已经确认；平台实现从计划范围移除。算法细节已由 S1 在第 4、5、9 节转为确定合同，仍不当作已实现能力。

### S1：数学与行为合同

**目的：** 让控制算法的每个量和每次调用只有一种解释。

**文档已完成。** 第 4 节固定相序、峰值电流、坐标正负号、电压归一化、先输出后推进相位，以及最终 duty 电压回算。第 5 节固定三个 API、配置/输入/输出字段、命令、状态与故障恢复。第 9 节给出 V01～V12、数值容差、长时间相位和独立 R-L 基准，后续可以不读取实现就计算预期结果。

电机参数、PI 增益与实际允许激励电流由使用方显式提供；第 9 节数值只作为验收夹具。本阶段没有新增头文件、控制器源码、示例或测试代码，也没有宣称通过实现验收。

示例按该合同初始化一次，每周期刷新输入并调用一次 `if_update()`；相位与积分跨周期保存，每次消费状态与输出有效性，禁用后需要新的 START。配置片段与持续调用示例分别标注，不将每次调用都重新初始化的函数作为周期模板。

### S2：共享基础

**目的：** 复用已经存在的能力，同时保证其定义适合新的完整链路。

**已完成。** 共享构建、PID 两阶段接口和测试基线见第 6 节；原 FOC 仍调用 `pid()`。实际 C 验证已覆盖最终输出回算、V06～V08 和全部调制扇区，原入口状态与固定参考一致。S3 通过共享目标链接同一份算法，不再以重复编入源码的方式复用。

FOC 与 S3 的 IF 均指向共享目标，公共头未引入设备类型。旧 PID 五个结构布局保持一致，PID 头/源继续保持各自的 GBK/CRLF 与 GBK/LF；S2 编辑文件按仓库 C99 门禁格式化，FOC 数学、控制和示例源码未改。

六个示例的职责、入口、宿主目标、重复符号与引用边界已登记在第 11 节，原示例均保留。它们通过当前行为基线，但仍需要在 S5/S6 改造成持续调用方式并完成迁移，不能把本阶段基线通过等同于迁移完成。

### S3：最小完整 IF

**目的：** 尽早证明“实际电流反馈 → 调节 → 电压 → duty”整条链路成立。

**已完成。** 独立对象、固定方向电流激励、软件相位和完整周期入口见第 6.3 节；两轴均通过真实反馈调节，经矢量限压、SVPWM 和最终 duty 电压回算更新积分。为遵守公开合同，基础参考整形、启停与故障处理也已接入，并有确定算例。

固定电角度下的独立 R-L 模型已通过正常、降母线、限压与恢复验收；12,960 组完整入口检查 duty 与电压约束。这只证明控制链路，不声称转子已在指定速度同步旋转。

### S4：完整运行行为

**目的：** 把基本控制链路扩展为可以稳定重复调用的控制器。

系统验收并完善 S3 已接入的电流/频率限速、正反向过零、保持、启停与故障恢复，补齐多实例交错运行、所有状态/命令组合、反复停止重启、零电流继续闭环及边界连续性。S3 的基本确定算例通过不替代本阶段的完整行为覆盖。

完成时所有公开状态都能通过确定输入到达和退出，配置错误不会造成无界循环或输出非有限数。

### S5：数值与闭环验证

**目的：** 用实际编译后的 C 代码证明行为，而不是只检查源码文本或复写一套 Python 公式。

测试调用真实 IF 入口，独立数值基准提供预期结果；R-L 模型覆盖基本电流跟踪、母线变化、饱和与退出饱和。长时间运行检查角度环绕、频率斜坡及累计精度，边界测试覆盖非法数值和异常恢复。

每个交付示例必须进入明确的编译、链接检查目标；没有 `main()` 的调用示例由最小宿主驱动连接实际库进行验证。对持续运行示例执行多个周期，检查初始化次数、相位推进、积分状态保持及有效输出消费。语法检查和示例文本检查不替代这些验证，也不将全部示例直接拼成一个含重复符号的可执行程序。

如使用更完整的电机模型，需记录其假设及能够证明的范围。电气模型测试不代替机械同步、带载启动或编码器测量精度的证据。

### S6：易用交付与示例收敛

**目的：** 让使用者用少量清晰接线得到完整 IF 功能。

提供初始化、每周期填写输入并调用更新、读取有效输出的最小示例，以及固定方向激励和连续扫频示例。示例展示数据契约，不内置具体 MCU 驱动；构建、参数单位、状态、诊断字段和验证命令全部可查。

按第 11 节清单整理现有示例：FOC 保留有感电流和电压接口示例；I-f 开环主示例在新 IF API 与 S5 验证通过后改用 IF；三环组合示例放到上层示例区；聚合示例在其各项用途均有独立替代后移除。迁移示例不改变现有 FOC 公开接口，也不同时重构其内部三环实现。

切换时同步更新 README、构建目标、读取示例的静态检查、编码扫描范围与相关文档链接。完成时模块可以独立构建并运行测试，示例状态由调用方明确持有，各功能只有一个主推示例入口，所有交付示例的编译、链接和所需多周期验证均通过。S0 至 S6 构成 IF 核心交付范围。

### S7：极对数识别应用

**目的：** 把 I-f 产生的电角度变化与外部观测的机械角变化关联起来。

应用负责对齐、扫描、采样和求解。在同步跟随且观测有效的前提下，使用展开后的角度估计：

```text
pole_pairs ≈ abs(delta_theta_e / delta_theta_mechanical)
```

应用检查足够位移、整数接近程度、正反向一致性及重复性，并拒绝无响应、失步或观测无效的结果。极对数及其质量标记留在应用结果中，不进入 IF 必需配置。

### S8：编码器换相校准应用

**目的：** 建立编码器机械角与电机换相电角度之间的方向和偏置关系。

上层组织“电流缓升对齐 → 正向扫描 → 反向扫描 → 求解 → 验证”。第一种实现优先采用分段移动、等待稳定、平均采样；连续扫描作为可替换应用策略。

在统一的 d 轴激励约定下，定义：

```text
theta_e = wrap(direction * pole_pairs * theta_encoder + offset_e)
offset_e = circular_mean(theta_command - direction * pole_pairs * theta_encoder)
```

计算要处理角度环绕、方向、观测时刻、机械滞后及异常样本。正反扫描可以减小部分方向相关误差；不能据此把激励角当作无误差的真实机械角。结果质量、保存与加载由应用负责。

### S9：按需扩展应用

**目的：** 在核心稳定后支持明确的具体用例，保持各项功能可单独验收。

候选包括编码器非线性补偿、双编码器关系校准、I-f 启动后的换相接管、特定扫描轨迹和诊断工具。高精度非线性补偿需要独立参考或可论证的测量方法，避免把摩擦、齿槽力矩和负载误差直接写成编码器误差。

这些项目没有统一的默认实施顺序，不因列入路线图就进入 IF 核心。定点或特殊数学优化也仅在真实数值与执行预算提出需求后单独规划。

## 8. 范围优先级与交付节点

| 优先级 | 范围 | 决策 |
|---|---|---|
| P0 | S0～S3：合同、共享基础与最小完整电流闭环 | 必须先贯通 |
| P1 | S4～S6：运行语义、实际 C 验证与易用交付 | IF 核心正式交付前完成 |
| P2 | S7、S8：极对数与编码器换相校准 | 独立应用，按实际需求实施 |
| P3 | S9：非线性补偿、启动接管、特殊数值实现等 | 有独立需求与验收后实施 |

第一个可审查节点是 S1 的合同与测试向量，第二个是 S3 的完整闭环，第三个是 S6 的独立模块交付。应用阶段使用已交付 IF，不反向给其增加编码器或电机识别字段。

## 9. 行为与验证追踪

| 编号 | 必须证明的行为 | 验证方式 | 阶段 |
|---|---|---|---|
| IF-001 | 没有编码器输入也能生成确定的软件相位与 duty | 实际 C 入口、独立数值基准 | S1、S3 |
| IF-002 | 零频率、非零电流时保持方向；停止状态不输出新的有效激励 | 状态迁移与保持测试 | S1、S4 |
| IF-003 | 正负频率、过零和环绕时相位连续且符号一致 | 多周期与边界测试 | S4、S5 |
| IF-004 | d/q 参考变化率和合成电流受配置约束 | 阶跃、斜坡、限幅向量测试 | S4、S5 |
| IF-005 | 两轴电流均由真实反馈调节 | R-L 模型闭环测试 | S3、S5 |
| IF-006 | 电压与调制限幅后，积分状态能够按合同恢复 | 持续饱和、母线变化、退出饱和测试 | S2、S5 |
| IF-007 | 非法输入明确失效，旧 duty 不被误认为本周期有效 | NaN/Inf、非法周期及母线输入测试 | S4、S5 |
| IF-008 | 复位和多实例互不泄漏运行状态 | 两实例交错运行、重新启动测试 | S4、S5 |
| IF-009 | IF 不需要极对数、编码器或设备 SDK | 公共头、依赖与独立构建检查 | S2、S6 |
| IF-010 | 共享调整不改变既有 PID/FOC 已接受行为 | 基线与调用方回归 | S2、S5 |
| EX-001 | 示例职责与控制 API 一致：FOC 有感电流、新 IF 开环电流、上层三环组合 | 示例归属清单与调用对象审查 | S2、S6 |
| EX-002 | 初始化一次，周期调用保留相位和 PI 状态，正确处理输出无效 | 连接实际 C 库的多周期宿主驱动 | S1、S5 |
| EX-003 | 每个交付示例均能独立编译和链接，无重复导出符号或入口冲突 | 明确的示例构建目标及编译告警检查 | S5、S6 |
| EX-004 | 新 IF 示例先通过验证，再替代原 I-f 主示例；原 FOC 能力保持兼容 | 替代前后使用合同检查、FOC 回归与迁移审查 | S5、S6 |
| EX-005 | 聚合示例移除后，静态检查、构建、编码扫描和文档不留下失效引用 | 对迁移后目标重新执行相关检查并核对引用 | S6 |
| APP-001 | 极对数结果具有足够位移及双向一致性 | 应用数据集、异常数据集与重复性检查 | S7 |
| APP-002 | 编码器方向与偏置能处理环绕和异常样本 | 圆周统计基准、正反扫描与使用验证 | S8 |

### 9.1 数值容差与确定算例

以下是完整 IF 实现的验收条件。S2 通过共享入口验证 V06～V08；S3 通过真实 IF 入口验证下表的基本确定算例，系统边界与完整长期矩阵继续由 S4/S5 验收。单步数值比较使用：A/V 绝对容差 `max(1e-5, 5e-6*该项配置幅值上限)`；Hz 容差 `max(1e-6, 5e-6*frequencyLimitHz)`；角度圆周距离容差 `1e-5 rad`；duty 绝对容差 `2e-6`。状态、错误码、有效性、零参考的终点和调用次数必须精确匹配，不能用数值容差掩盖状态错误。

| 编号 | 输入或已知条件 | 必须得到的结果 |
|---|---|---|
| V01：d 轴与零序 | 相电流 `[1,-0.5,-0.5] A`，theta = 0；另测整体加 `0.2 A` 的 `[1.2,-0.3,-0.3]` | 两组均为 `i_alpha = 1, i_beta = 0, id = 1, iq = 0 A` |
| V02：q 轴正号 | 相电流 `[0,sqrt(3)/2,-sqrt(3)/2] A` | theta = 0 时 `id = 0, iq = 1 A`；theta = pi/2 时 `id = 1, iq = 0 A` |
| V03：电流圆盘与限速 | 原参考零，目标 `[3,4] A`，Imax = 2 A，Ts = 0.01 s，电流斜率 10 A/s | 限幅目标 `[1.2,1.6] A`，本周期参考 `[0.06,0.08] A`；限幅和斜坡标记均置位 |
| V04：启动时序 | 初相位 0，频率目标 1 Hz，频率斜率 10 Hz/s，Ts = 0.01 s | 首周期 `thetaUsed = 0`、`f_ref = 0.1 Hz`、`deltaTheta = 0.0062831853 rad`；下一周期才使用推进后角度 |
| V05：正反向过零 | 旧频率 +0.05 Hz，目标 -1 Hz，单步上限 0.1 Hz | 本周期 0 Hz，下一周期 -0.1 Hz；相位不重置，电流目标不翻号 |
| V06：电压与 duty | 实际限压后的 `vd = 12 V, vq = 0`，theta = 0，Vbus = 24 V，eta = 0 | duty = `[0.875,0.125,0.125]`；由 duty 重建仍为 `[12,0] V` |
| V07：圆形边界 | eta = 0.05，Vbus = 24 V，用户上限足够大，dq 电压位于正 d 轴边界，theta = pi/6 | Vlimit = `12.4707658 V`，duty = `[0.95,0.5,0.05]`；eta = 0 时同角度边界为 `[1,0.5,0]` |
| V08：矢量回算 | Ts = 0.01 s，两轴 `e = 1 A, kp = 1 V/A, ki = 10 V/(A*s), kaw = 2 A/V, J_old = 0`，Vlimit = 1 V，积分限值 1 V | 原始电压 `[1,1] V`，实际电压各为 `1/sqrt(2) V`；两轴 `J_new = 0.041421356 V`，不能是未回算的 0.1 V |
| V09：正常停机 | 入停机频率 +0.2 Hz、电流参考 `[0.2,0] A`，两项单步上限均为 0.1 | 四次 STOP/KEEP 更新依次为 `(f,id)=(0.1,0.2),(0,0.2),(0,0.1),(0,0)`；前三次输出有效，第四次 STOPPED/无效 |
| V10：保持与立即禁用 | RUNNING、频率目标零、电流目标非零；随后 DISABLE 且 sampleValid=false | 保持阶段相位不变且输出有效；DISABLE 当次 STOPPED/无效，不误报采样故障 |
| V11：故障锁存 | RUNNING 收到 NaN 电流，再送有效数据与 START，再 reset | 首次 NUMBER/FAULT 且无效；第二次仍 NUMBER/FAULT；reset 后 STOPPED，只有随后 START 才运行 |
| V12：配置与生命周期 | 零周期、负限值、eta = 0.5、过大的 `ki*kaw*Ts`、不可推进的斜坡；活动状态 reset/init | 前一组 CONFIG 且对象不变；活动状态 STATE 且对象不变；两种失败都不能偷偷重置相位或积分 |

V06～V08 是算法子链的数值条件；通过完整入口测试时，应使用满足这些原始电压条件的反馈、参考和 PI 配置，或在共享组件层单独验算，不借助测试专用入口修改 IF 私有状态。补充覆盖三相重构顺序、d/q 两轴及各电压扇区、幅值零和边界、低母线、有限但越界初相位、Inf、非法 action、NULL、无效输出字段清零和两实例交错运行。

### 9.2 长时间相位验收

使用实际 C 周期入口，Ts = 100 us，频率限值 10 Hz，初相位分别为 0、0.7、5.9 rad；在参考已到稳态后，对 `0, +/-0.0001, +/-0.001, +/-1, +/-10 Hz` 分别运行至少 1,000,000 个周期。输入采样保持有效，初相位仅在启动时设置。

独立双精度基准使用实际输入的 float 周期、频率和每次发布的参考序列计算，不读取内部下一相位。每周期输出角度有界，相位只在有效更新后前进；相对于理想积分的圆周距离全程 <= 0.005 rad，零频漂移 <= 单步角度容差。低频必须有累计推进，不能以一直停在同一 float 值的方式满足单步误差；反向与环绕不产生额外跳变。

### 9.3 独立 R-L 闭环基准

S3 已通过第 6.3 节的实际 C 模型测试执行本基准。模型无反电动势、无机械运动；在静止 alpha/beta 坐标各使用：

```text
a = exp(-R*Ts/L)
i[k+1] = a*i[k] + (1-a)*v_applied[k]/R
```

模型从 IF 的最终三相 duty 与本周期母线电压独立重建电压，再推进模型、生成下一周期三相反馈；不能把 IF 内部的参考或原始 PI 电压直接当作模型施加量。重建公式由测试基准独立实现，不调用被测变换或调制函数。

| 参数组 | 固定值 |
|---|---|
| 电气模型 | R = 1 ohm，L = 1 mH，Ts = 100 us，初始电流为零 |
| 正常配置 | Vbus = 24 V，busMin = 1 V，电流限值 2 A，用户电压上限 10 V，eta = 0.05 |
| PI | 两轴 kp = 1 V/A，ki = 1000 V/(A*s)，kaw = 1 A/V，积分限值 10 V |
| 参考轨迹 | 电流斜率 10000 A/s，频率限值 10 Hz，频率斜率 1000 Hz/s，目标频率零 |
| 激励 | 初相位分别取 0、pi/3；d 轴与 q 轴各测一次从 0 到 1 A 的启动阶跃 |

正常配置下，10 ms 后到 50 ms 的激励轴跟踪误差 <= 0.02 A，未激励轴绝对值 <= 0.01 A，全程激励轴峰值 <= 1.05 A。稳态后母线从 24 V 变为 6 V，继续运行 20 ms，末 10 ms 仍满足同一跟踪指标，所有有效 duty 满足裕量约束。

饱和用例将用户电压上限及积分限值同时改为 0.5 V，其余不变：1 A 目标保持 100 ms 后，电流应在 0.5 +/- 0.02 A 内，并持续报告电压受限，积分不得越界；再将目标改为零，50 ms 后两轴绝对电流均 <= 0.02 A。V08 另行检查矢量限幅的回算公式，避免仅凭积分硬限幅就宣称抗饱和正确。

以上数值只定义可复现的电气链路回归夹具，不是实际电机的推荐调参，也不证明机械同步或编码器精度。真实应用的激励参数和机械验收由应用另行确定。

## 10. 参考项目与具体借鉴内容

以下源码链接固定到已阅读的提交；用途是定位参考行为，源代码采用与许可证记录仍需按实际引入范围判断。默认优先复用本仓库基础组件，再独立实现所需行为，不整仓移植控制框架。

| 项目与来源 | 具体内容 | 推荐吸收的设计 | 归属 |
|---|---|---|---|
| [VESC 开环电流入口](https://github.com/vedderb/bldc/blob/abc9217fb2b7ee3821f1742bc32b269173643319/motor/mcpwm_foc.c#L878) | `mcpwm_foc_set_openloop_current()` 与 `mcpwm_foc_set_openloop_phase()`；分别提供电流与转动频率、固定相位电流激励 | 区分连续旋转和固定方向激励，两者共用电流闭环 | IF 核心 |
| [VESC 编码器检测](https://github.com/vedderb/bldc/blob/abc9217fb2b7ee3821f1742bc32b269173643319/motor/mcpwm_foc.c#L1518) | `mcpwm_foc_encoder_detect()`；d 轴电流激励、比例与方向检测、正反向停留采样、sin/cos 求偏置 | 激励与求解分离；多个位置和两个方向共同估计 | S7、S8 应用 |
| [moteus 电流校准入口](https://github.com/mjbots/moteus/blob/8f747f4ac448d117c1390b77ca2d80c27e751a56/fw/board_debug.cc#L562) | `d cali`，通过 `fixed_current_override` 组织正反向电流扫描，并记录相位、编码器和相电流 | 校准应用调用统一激励能力，同时保留可分析的原始数据 | S8 应用 |
| [moteus 校准求解](https://github.com/mjbots/moteus/blob/8f747f4ac448d117c1390b77ca2d80c27e751a56/lib/python/moteus/calibrate_encoder.py) | 扫描数据解析、方向和极数分析、偏置拟合、质量与错误结果 | 将求解和质量判断独立于快速电流环 | S7、S8 应用 |
| [ODrive 历史开源固件](https://github.com/odriverobotics/ODrive/blob/3a2e4dd1bfbda9e4c534d5c7d8428a99c361e783/Firmware/MotorControl/encoder.cpp#L320) | `Encoder::run_offset_calibration()`；正反扫描、无响应检查、编码器分辨率/极对数关系检查和偏置估计 | 应用流程必须包含结果合理性检查与明确失败出口 | S7、S8 应用 |
| [SimpleFOC 控制实现](https://github.com/simplefoc/Arduino-FOC/blob/b3d8f3931342ae68a980d0140e24b9048eba098b/src/common/base_classes/FOCMotor.cpp#L580) | `velocityOpenloop()`、`angleOpenloop()` 与 `loopFOC()` 中的 `foc_current` 路径 | 角度来源与电流调节职责可分，组合后提供完整开环电流控制 | IF 语义和示例 |

补充阅读：[moteus 电流模式换相校准说明](https://blog.mjbots.com/2025/04/10/current-mode-commutation-calibration-in-moteus/)、[SimpleFOC 开环控制文档](https://docs.simplefoc.com/velocity_openloop)、[moteus 编码器补偿工具](https://github.com/mjbots/moteus/blob/8f747f4ac448d117c1390b77ca2d80c27e751a56/utils/compensate_encoder.py)。

推荐阅读顺序：本地 FOC/PID → VESC 的开环电流与固定相位接口 → moteus 的电流扫描与数据求解 → ODrive 的失败判定 → SimpleFOC 的组合与使用方式。

参考边界：

- VESC 相关文件声明 `GPL-3.0-or-later`；当前计划以控制行为和接口语义为参考，不默认复制其实现。
- moteus 使用 Apache-2.0；其 C++、诊断命令、设备对象和工具链不是 IF 核心的依赖。
- ODrive 对应开源固件使用 MIT；[仓库说明](https://github.com/odriverobotics/ODrive/blob/3a2e4dd1bfbda9e4c534d5c7d8428a99c361e783/README.md)明确该历史开源线不再积极开发，只将其作为可审查的算法与流程参考。
- SimpleFOC 使用 MIT；参考其真实电流采样路径，电流估计不能替代本计划要求的电流反馈闭环。其自适应调用间隔不直接照搬，IF 使用确定的控制周期。
- moteus 的工具可以按采样噪声条件选择不同校准激励；本 IF 的输出失效不自动降级成电压开环，应用若需要这种策略应显式定义。

## 11. 现有示例整理与预期文件组织

### 11.1 当前事实与逐文件处理计划

现有六个示例均使用局部 `Foc` 对象，初始化后只执行一次 `foc_loop()`，展示配置和单次调用。S2 已在 [FOC 构建](../foc/CMakeLists.txt)加入六个独立宿主目标，使用 [示例宿主](../tests/test_example.c)分别包含原始示例并链接真实库，观测初始化/周期调用次数及输出。两次重复调用确认当前对象会重建，因此已证明编译、链接和当前行为，尚未证明可持续保持相位与积分。

[聚合示例](../foc/examples/flat_vf_if_example.c)和[开环电流示例](../foc/examples/open_loop_current_example.c)都导出 `app_foc_if_open_loop_startup_example()`，整理时需要消除重复定义。[现有静态检查](../foc/tests/test_foc_flat_vf_if.py)还直接读取聚合文件，不能单独删除该文件而留下失效检查。

下表仍是后续源码迁移清单。S2 已新增构建与测试基线，但没有移动、改名、删除或重写六个原始示例；迁移条件与 Q6、Q7 决策保持不变。

| 当前文件 | 当前用途 | 计划处理与目标归属 | 实施条件与验证 |
|---|---|---|---|
| [current_loop_example.c](../foc/examples/current_loop_example.c) | `FOC_MODE_IF + FOC_ANGLE_SENSOR`，有感两轴电流控制 | 留在 `foc/examples/`，作为有感电流环主示例；明确现有 IF 模式名不代表新 I-f 模块 | 改为初始化一次、按新样本周期更新；保留 FOC API，完成独立构建和多周期验证 |
| [minimal_example.c](../foc/examples/minimal_example.c) | `VF + OPEN_LOOP`，直接给定电压 | 留在 `foc/examples/`，拟命名为 `voltage_open_loop_example.c`，准确表达电压开环用途 | 更新入口说明与引用，验证电压输入、角度推进、输出约束及持续调用 |
| [with_pid_controller_example.c](../foc/examples/with_pid_controller_example.c) | 接收外部 dq 电压值，没有调用外部 PID 算法 | 留在 `foc/examples/`，拟命名为 `external_voltage_example.c`，展示外部电压接口 | 使用明确的电压输入合同，验证输入更新和无效输出处理；不声称已演示外部 PID 实现 |
| [open_loop_current_example.c](../foc/examples/open_loop_current_example.c) | `IF + OPEN_LOOP`，依赖现有 `Foc` 的 I-f 开环激励 | 新 IF 可用后改用其对象/API，迁入 `IF/examples/`，作为 I-f 连续运行主示例；原 FOC 对应功能保留兼容 | 先完成新 API、S5 及替代示例验证，再切换主入口；迁移包含控制调用重写，不能只移动文件 |
| [motion_loop_example.c](../foc/examples/motion_loop_example.c) | 通过现有 `Foc` 组合位置、速度、电流三环 | 移入上层运动控制示例区，拟放在 `CodingKit/examples/motor_control/`，展示控制器组合 | 独立目标验证完整调用；更新构建、文档与扫描范围；本次归属调整不要求改写 FOC 内部三环实现 |
| [flat_vf_if_example.c](../foc/examples/flat_vf_if_example.c) | 聚合电压开环、I-f 开环及三环示例，与单项文件重叠 | 将三项用途分别收敛到上述主示例，全部有替代后移除聚合文件 | 同步调整静态检查的输入对象并保留其字段/接口检查意图；确认无重复符号、旧构建项或失效链接 |


S2 入口与目标基线如下（所有目标均通过）：

| 原文件 | 当前导出入口 | 独立 CTest 目标 |
|---|---|---|
| `current_loop_example.c` | `app_foc_if_current_loop_example()` | `foc_baseline_current_loop_example` |
| `minimal_example.c` | `app_foc_vf_minimal_example()` | `foc_baseline_minimal_example` |
| `with_pid_controller_example.c` | `app_foc_with_external_pid_example(AppPidOutput, AppPidOutput)` | `foc_baseline_with_pid_controller_example` |
| `open_loop_current_example.c` | `app_foc_if_open_loop_startup_example()` | `foc_baseline_open_loop_current_example` |
| `motion_loop_example.c` | `main()`，宿主中局部改名后调用 | `foc_baseline_motion_loop_example` |
| `flat_vf_if_example.c` | `app_foc_vf_open_loop_example()`、`app_foc_if_open_loop_startup_example()`、`app_foc_if_three_loop_example()` | `foc_baseline_flat_vf_if_example` |

引用与扫描基线：本 README 按文件链接六个示例；[宿主构建清单](../tests/CMakeLists.txt)按文件建立独立目标；`test_foc_flat_vf_if.py` 直接读取聚合文件；`check_static_boundary.py` 递归扫描 FOC 的 src/examples/tests/docs，编码检查覆盖 src/examples。聚合文件与独立 I-f 文件仍有同名入口，当前用独立目标隔离，S6 去重后才能合并相关符号空间。FOC 当前文件实际为 UTF-8，原编码说明中的 GBK 声明已按事实修正，检查器继续兼容两种编码。

### 11.2 迁移顺序与验证要求

1. **S1 合同与 S2 基线已完成。** 六个源文件、入口、引用与当前行为见第 11.1 节；新主示例仍需满足 S1 的持续调用合同。
2. **S3～S5 建立新 IF 与替代示例。** 先完成可持续调用的对象生命周期和实际 C 验证，再用新 IF API 建立开环电流示例；原示例在此之前保留。
3. **S6 按职责收敛。** 保留或重命名 FOC 基础示例、切换 I-f 主示例、上移三环组合示例；随后移除已经完成用途替代的聚合文件。
4. **S6 同步引用和验证入口。** 更新本 README 的旧示例链接、FOC README、示例构建目标及 `test_foc_flat_vf_if.py` 的读取路径与检查对象；核对 `foc/tools/check_c_gbk.py`、`foc/tests/check_static_boundary.py` 和编码说明的扫描范围仍覆盖对应文件。
5. **从干净构建验收。** 每个交付示例独立编译、链接并完成其所需宿主运行；验证多周期状态保持、有效输出消费、共享组件及原 FOC 能力回归。静态文本检查继续承担接口约束，不能替代实际执行。

如果替代示例未通过验证，保留原示例和主入口说明；若切换后发现回归，按同一迁移阶段一起恢复源码归属、构建目标、检查输入和文档引用，避免只恢复其中一项。

### 11.3 目标组织

下面是 S3～S6 的目标组织。S3 已交付 README、CMake、`src/` 和 `tests/`；`examples/` 是 S5/S6 计划产物，尚未创建。

```text
IF/
├── README.md
├── CMakeLists.txt
├── src/
│   ├── if_controller.h
│   └── if_controller.c
├── examples/
│   ├── open_loop_current_example.c
│   └── fixed_current_example.c
└── tests/
    ├── CMakeLists.txt
    ├── test_if_control.c
    └── test_if_rl.c
```

`open_loop_current_example.c` 展示连续电流激励，`fixed_current_example.c` 展示固定方向激励；两者都采用新 IF API 和明确的初始化/周期调用方式。FOC 保留有感电流、电压开环及外部电压接口示例；上层三环示例与之后的校准应用均放在上层示例位置。

共享数学和 PID 继续使用唯一权威源码。极对数、编码器校准的实现放在独立应用位置或使用工程中；若以后形成可复用的校准算法模块，再按其职责单独组织，不塞入 `if_controller.c`。上图仅 `examples/` 尚未创建。

## 12. 验证入口、兼容与完成标准

从 `controller/` 目录可同时构建原 FOC/PID 与新 IF，并执行 12 项 CTest：

```text
cmake -S . -B build-host -DBUILD_TESTING=ON
cmake --build build-host
ctest --test-dir build-host --output-on-failure
```

也可分别以 `pid/`、`foc/` 为源目录配置，原库目标保持可用；宿主编译器与生成器由使用者指定。`BUILD_TESTING=OFF` 只构建库。

从 `IF/` 目录也可独立构建；启用测试时执行 `pid_runtime`、`if_control`、`if_rl` 三项，不编译完整 FOC 对象：

```text
cmake -S . -B build-host -DBUILD_TESTING=ON
cmake --build build-host
ctest --test-dir build-host --output-on-failure
```

调用方通过 `target_link_libraries(app PRIVATE if_controller)` 获得头文件与共享库传递依赖；手工链接需同时提供 IF、PID、数学和 SVPWM。先以 `{0}` 建立 `IfController`，填完整 `IfConfig` 并检查 `if_init()`；每周期填一个 `IfInput`，调用一次 `if_update()`，同时检查返回值和 `outputValid` 再应用 duty。停止态不会自行开始；`reset()` 后仍须发送新的 START。完整字段、单位与优先级见第 5 节，不读写对象内部成员。

验证分为公共头与依赖检查、实际 C 行为测试、模型闭环测试、已有调用方回归及具体应用验证。源码文本检查只承担静态约束，不能代替运行真实 C 控制器。

兼容策略是先保留现有 FOC/PID 的接口和行为；共享调整独立验证。若共享组件出现回归，先撤回该阶段调整，不用放宽 IF 测试或修改旧调用方预期来掩盖问题。代码、合同、示例和测试在各阶段同步更新，本 README 始终区分计划与已完成能力。

IF 核心交付完成需同时满足：完整两轴电流闭环、软件角度连续、最终限幅与积分状态匹配、状态与异常行为明确、无设备和应用反向依赖、实际 C 测试通过，以及最小示例可独立运行。S6 还必须完成第 11 节的主示例迁移、三环示例归属、去重和引用同步验收。编码器校准是否完成不影响这个核心定义；它由 S8 自己的验收决定。

## 13. 设计树与下一步

```text
I-f 是核心需求（已确认）
├── 完整控制链，IF 拥有独立对象（已确认）
│   ├── 共享 PID / 变换 / 调制与实际 C 基线（S2 已完成）
│   ├── 单位、时序、限幅、启停合同（S1 文档已完成）
│   └── 独立 IF、完整电流链与 R-L 基准（S3 已完成）
├── float + 物理单位（已确认）
│   └── 数值容差、V01～V12 与模型参数（S1 文档已完成）
├── 纯通用算法，不安排平台阶段（已确认）
├── 示例按职责归属（Q6、Q7 已确认）
│   ├── 新 IF 验证通过后承接 I-f 开环主示例，FOC 保留兼容能力
│   ├── FOC 保留有感电流和电压接口示例
│   └── 三环示例上移，聚合示例在用途替代后移除
└── 识别与校准是上层应用（已确认）
    ├── 极对数识别（S7）
    ├── 编码器换相校准（S8）
    └── 其他具体应用（S9 按需立项）
```

S3 已打通独立 IF 的固定方向激励、软件相位、两轴电流闭环、矢量限压和最终 duty 输出，实际 C、独立 R-L 与原路径兼容结果见第 6.3 节。下一步进入 S4，系统覆盖运行行为、多实例隔离和命令边界；第 9.2 节完整百万周期矩阵与持续调用示例仍由 S5 完成。Q6、Q7 的源码迁移在替代示例通过验证后于 S6 收敛，本阶段未迁移原示例。
