# 参数与信号

本页记录基础边界层版本。新增sigmoid的本地M入口、输入/过程/输出和6组Scope全部见[SIGMOID_PARAMETERS.md](SIGMOID_PARAMETERS.md)，两种版本的日志列不同。

## 配置参数

默认工况的可执行入口为[smo_test_parameters.m](smo_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_smo_test('SlidingModeObserverTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../../docs/guide/PARAMETER_USAGE.md).

定义：[smo_parameters.m](smo_parameters.m)，修改物理配置后调用 [refresh_smo_parameters.m](refresh_smo_parameters.m)。PLL 参数引用 [相位跟踪](../../../相位跟踪/parameter/README.md)，Ts 必须相同，MinMagnitude 设置为 MinEmf。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e-6 | s | 观测更新周期 |
| Rs / L | 0.5 / 1e-3 | Ω / H | 每相电阻和 SPMSM 公共电感；Ld=Lq |
| Flux / PolePairs | 0.035 / 4 | Wb / 1 | 测试真值及机械速度换算；不进入基础预测更新 |
| SlidingGain / Boundary | 30 / 1 | V / A | 注入幅值与电流误差边界层 |
| FilterHz | 600 | Hz | 注入低通截止频率 |
| MinEmf / MinOmega | 1 / 30 | V / 电角 rad/s | 幅值和速度有效门限 |
| Compensate | 1 | 0/1 | 离散 LPF 稳态相移补偿开关 |
| A / B | exp(-Rs Ts/L) / (1-A)/Rs | 1 / A/V | R-L 精确离散系数 |
| FilterA | exp(-2π FilterHz Ts) | 1 | 一阶滤波记忆系数 |
| BoundaryPole | A-B SlidingGain/Boundary，默认约 -0.506 | 1 | 边界层内线性误差极点，要求绝对值 <1 |

## 输入信号

| 名称 | 单位 | 类型或初值 | 来源/用途 |
|---|---|---|---|
| u_alpha / u_beta | V | double，有限 | 区间 [kTs,(k+1)Ts) 实际作用电压；测试为解析信号采样后 ZOH |
| i_alpha / i_beta | A | double，有限 | k 时刻采样电流，与 i_hat[k] 比较 |
| direction | -1/0/+1 | double | 已知反转/无效/正转；变化当拍重置 |
| enable / reset | 0/1 | double | 禁能重置，复位优先 |
| theta_true / omega_true | rad / rad/s | 测试专用 | 不进入观测器，只供 Scope 和误差计算 |

## 过程变量

| 名称 | 单位 | 类型或初值 | 所在块及计算 |
|---|---|---|---|
| current_state | A，二元素向量 | [0;0] | Unit Delay 保存 i_hat[k] |
| current_error | A | double | i_hat[k]-i[k] |
| sliding_injection | V | double，逐轴限幅 | K sat(error/Boundary) |
| emf_state | V，二元素向量 | [0;0] | 对 z 低通，状态更新包含一拍 |
| emf_angle | rad | double | atan2(-direction e_alpha,direction e_beta) |
| previous_speed | 电角 rad/s | 0 | PLL 上一拍速度，打断补偿的代数环 |
| filter_phase | rad | double | atan2(sin(omega_prev Ts),cos(omega_prev Ts)-FilterA) |
| reset_any / active | 0/1 | boolean | 复位/方向变化与有效运行资格 |

## 输出信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| theta_e_hat | 电角 rad | double / 0 | PLL 当前拍角状态 |
| omega_e_hat | 电角 rad/s | double / 0 | PLL 有界速度；机械速度除以 PolePairs |
| valid | 0/1 | double / 0 | PLL 资格、速度与方向共同判定；不是实际角误差保证 |
| emf_alpha / emf_beta | V | double / 0 | 滤波反电势 |
| i_hat_alpha / i_hat_beta | A | double / 0 | 当前预测电流 |
| injection_alpha / injection_beta | V | double / 0 | 有界滑模注入 |
| phase_measured | 电角 rad | double | 方向与 LPF 相移处理后的相位 |
| emf_magnitude | V | double / 0 | sqrt(e_alpha²+e_beta²) |
| phase_error | rad | double / 0 | PLL 包角相位误差 |

## Scope 通道

以下顺序已与R2026b实际模型连接核对；五组Scope各有一个向量输入端口，序号为元素顺序。所有速度为电角rad/s。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1 | theta_true | stimulus 第8列 | rad | 解析真值 |
| AngleScope 2 | theta_e_hat | SMO 输出1 | rad | 估算角度 |
| AngleScope 3 | angle_error | angle_error 包角块 | rad | 估算减真值 |
| SpeedScope 1 | omega_true | stimulus 第9列 | rad/s | 解析速度 |
| SpeedScope 2 | omega_e_hat | SMO 输出2 | rad/s | 估算速度 |
| EmfScope 1 | emf_alpha | SMO 输出4 | V | α 轴反电势 |
| EmfScope 2 | emf_beta | SMO 输出5 | V | β 轴反电势 |
| EmfScope 3 | emf_magnitude | SMO 输出11 | V | 低速可观测幅值 |
| CurrentScope 1 | i_alpha | stimulus 第3列 | A | α 轴电流输入 |
| CurrentScope 2 | i_hat_alpha | SMO 输出6 | A | α 轴预测 |
| CurrentScope 3 | i_beta | stimulus 第4列 | A | β 轴电流输入 |
| CurrentScope 4 | i_hat_beta | SMO 输出7 | A | β 轴预测 |
| StatusScope 1 | direction | stimulus 第5列 | -1/0/+1 | 已知方向与无效区 |
| StatusScope 2 | enable | stimulus 第6列 | 0/1 | 使能 |
| StatusScope 3 | reset | stimulus 第7列 | 0/1 | 复位 |
| StatusScope 4 | valid | SMO 输出3 | 0/1 | 有效标志 |
| StatusScope 5 | phase_error | SMO 输出12 | rad | PLL 相位误差 |

trace 的 22 列依次为：u_alpha、u_beta、i_alpha、i_beta、direction、enable、reset、theta_true、omega_true、theta_e_hat、omega_e_hat、valid、emf_alpha、emf_beta、i_hat_alpha、i_hat_beta、injection_alpha、injection_beta、phase_measured、emf_magnitude、phase_error、angle_error。

注入仅记录到 trace 第17/18列，没有独立 Scope 通道；不把 trace 列号当成示波器端口号。相位包角图会在 ±π 处跳变，判断误差用第22列，不能直接相减两条锯齿曲线。

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $R_s$ | cfg.Rs | Ω | 直接使用；失配试验时真实值与估计值分别设置 |
| $L_d=L_q$ | cfg.L | H | SPMSM公共电感；原表mH乘$10^{-3}$，局部符号$\ell_{sp}$ |
| $\psi_m$ | cfg.Flux | Wb | 直接使用；此字段在emf/smo独立夹具中的作用另按本页说明 |
| $P$ | cfg.PolePairs | 计数 | 数值不换算；原表单位空白，保留原表 |
| $\hat\theta_r$ | AngleTracking/PLL输出1；pllCfg.Theta0给定初始状态 | 电角rad | 这里PLL的输入已构造成转子电相位 |
| $\hat\omega_r$ | AngleTracking/PLL输出2 | 电角rad/s | 机械rad/s乘P得到电角rad/s；估计机械速度为本输出除P |

### 本模块局部量

$\ell_{sp}=L_d=L_q$为SPMSM公共电感；工程L使用H。$a_i,b_i$是R-L离散系数，分别映射工程A、B，后者单位A/V，不能解释为原表黏性阻尼$B$。滑模误差、边界层、sigmoid斜率及PLL相位按各分支单独定义。
