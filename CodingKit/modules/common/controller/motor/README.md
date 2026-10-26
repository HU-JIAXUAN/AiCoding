# 电机控制可组合算法

本目录补充[FOC 数学与调制](../foc/README.md)、[PI](../pid/README.md)、[I-f](../IF/README.md)和[激励](../Signal%20generator/README.md)，不维护第二份变换、PI或SVPWM实现。算法不访问寄存器、设备、动态内存或文件。输入结构及单位以 [motor.h](motor.h) 为准，唯一实现是 [motor.c](motor.c)，独立参考和实验入口是 [run_tests.py](run_tests.py)。

## 立即验证

在包含 `CodingKit` 的仓库根目录执行：

```powershell
python CodingKit/modules/common/controller/motor/run_tests.py
python CodingKit/modules/common/controller/motor/run_tests.py --cc gcc --output build/motor-primitives
```

不传 `--output` 时创建临时编译目录并清理；传入时保留构建日志、源文件SHA256及 `results.json`。失败返回非零退出码，默认同时编译 `-O0/-O2 -std=c99 -Wall -Wextra -Werror -pedantic`。只依赖 Python 标准库和 GCC，无 NumPy/SciPy 运行依赖。

也可通过现有 controller CMake 入口构建 `motor_primitives` 并运行 `ctest`，`motor_golden` 调用同一个测试入口。交叉编译只构建库，不尝试运行目标程序。宿主测试的编译器/解释器是构建依赖，不进入目标固件。

## 公共约定

- 电流为相电流峰值A，电压为相对电机中性点的电压V；幅值不变Clarke/Park，q轴超前d轴90°，正电角速度从d转向q。
- `McMotor` 的电阻为每相Ohm，电感H，磁链为相峰值Wb。`mc_dq_ff`、约束模型使用电角速度rad/s；RL静止检查使用机械速度rad/s。不能直接代入RMS电流、线电压、电感mH或机械rpm。
- 参数快照在整个一次调用中不可变；应用在周期边界发布非零 `version`，`mc_mtpa`、RL、DOB、PLL拒绝不一致版本。纯函数的跨模块版本一致性由调用方快照负责。
- 每轴独立保存RL/DOB/PLL/滤波器/PI状态，一个执行者拥有一个实例。没有后台任务和隐含全局状态。重新调用对应 `init` 重置；滤波器状态用 `{0}` 清零，PI使用其正式接口。
- 成功才写输出，失败保留输出和状态。唯一例外：DOB收到 `valid=false` 会清除速度导数基准但保留估计，返回错误且不写输出；下一有效帧只重建基准，避免跨丢帧求导。
- 失败后输出缓冲区中的旧值仍是旧值，调用方必须先检查状态。保护逻辑、PWM使能和故障锁存属于应用/硬件，不由数值函数隐式接管。
- 状态码稳定：`NULL=1`、`NUMBER=2`、`RANGE=3`、`STALE=4`、`REVISION=5`、`SAMPLE=6`、`EVIDENCE=7`、`CONSTRAINT=8`、`DUPLICATE=9`，成功为0。秩不足不是一个可发布的参数估计。

## 确定性能力与边界

| 入口 | 实际能力 | 明确边界 |
|---|---|---|
| `mc_dq_ff` | 电流耦合与反电势电压前馈 | 常参数Ld/Lq/磁链；不含Rs、限压或重复延迟预测 |
| `mc_pi_design`、`mc_pi_cfg` | 精确ZOH RL对象的离散PI系数与额外延迟准入；当前误差下参数切换的比例/积分状态补偿 | 使用正式 `pid_pi_eval/track`；无饱和时的极点抵消不等于真实电机已整定 |
| `mc_rl_init/add/fit` | 固定Ts、静止RL的精确ZOH ARX批量OLS与归一化秩检查 | 不是在线RLS；不估计磁链/惯量/交叉饱和；输入噪声会造成OLS偏差 |
| `mc_align_angle` | 从物理锁存时刻到目标时刻的有界匀速预测 | 拒绝过期、时间倒退、超预测量和重复预测；不把收包完成当锁存 |
| `mc_mtpa`、`mc_torque`、`mc_check_limits` | 常参数SPM/正凸极IPMSM的固定电流幅值MTPA、转矩和稳态限流/限压检验 | 不支持反凸极/磁链表；约束检查不是完整弱磁/MTPV调节器 |
| `mc_deadtime` | 标定等效时间误差、电流零点平滑、去零序的相电压补偿 | 必须已知标定幅值/极性；补偿后最终可实现电压仍要回馈anti-windup |
| `mc_friction`、`mc_mech_ff` | 平滑库仑/粘性/Stribeck模型；J·加速度+B·速度+已知负载 | 负载/传动比/重力坐标由应用统一；不把总扰动直接称为摩擦参数 |
| `mc_dob_init/update` | 正外部阻力矩约定的一阶Q滤波DOB；精确ZOH滤波系数预计算 | `appliedTorqueNm` 是两速度样本之间实际平均转矩；速度差分会放大噪声 |
| `mc_notch`、`mc_filter` | 预畸变双线性陷波、量化后Schur稳定检查、每实例滤波状态 | 参数设计离线运行；极窄/极低频float退化时拒绝，不能仅看连续极点 |
| `mc_pll_init/update` | 二阶相位跟踪PLL、离散Jury准入、速度积分限幅 | 不是反电势/磁链/HFI观测器；每次成功后角度属于下一采样时刻k+1 |
| `mc_dual_error`、`mc_schedule`、`mc_ripple` | 展开位置传动比与一致性、整数多速率相位、最多16阶机械角谐波 | 双反馈须先对齐零点/时刻；调度cycle是应用帧序号，回绕须在应用定义；不是完整两惯量控制器 |
| `mc_traj_plan/sample` | 受V/A/J上限约束的静止到静止五次轨迹，整周期取整及同一时刻PVAJ | 不支持非零初态、在线改目标、最短时间S曲线或急停规划 |
| `mc_frf` | 最多4096点整周期单频DFT，H=Y/U及幅相 | 必须已知注入点与同步采样；单记录不估相干性，不证明闭环估计无偏 |
| `mc_phase_current` | 双/三电阻的有效相掩码、两相零和重构、三相独立测量残差 | 三相需要同一物理时刻；两相不能检验缺失相的独立故障 |
| `mc_bus_current` | 两个显式有源开关状态的单DC电阻重构，窗长/秩/年龄/误差界检查 | 不是按sector猜测；不能替代PWM移相、最小脉宽和真实放大器建立时间验证 |

`mc_pi_design`、RL拟合、陷波设计、轨迹规划与DFT用于离线/慢任务。其余函数的步骤有固定上限，但 `sqrt/fmod/remainder/tanh` 等库函数的实际周期、double成本、堆栈和Flash等待必须用目标编译器与板测另行验证；这里不提供虚构的WCET。

## 数学及离散依据

统一模型：

```text
vd = R*id + Ld*did/dt - omega_e*Lq*iq
vq = R*iq + Lq*diq/dt + omega_e*(Ld*id + psi)
Te = 1.5*p*(psi + (Ld-Lq)*id)*iq
```

因此 `mc_dq_ff` 输出 `[-omega_e*Lq*iq, omega_e*(Ld*id+psi)]`，PI负责余下电压。一个补偿只添加一次，前馈本身不做最终限制。

对静止RL及一个区间内实际电压ZOH：`i[k+1]=a*i[k]+b*v[k]`，其中 `a=exp(-R*Ts/L)`、`b=(1-a)/R`。RL估计器统计六个二阶量并解析求a/b，再还原 `R=(1-a)/b`、`L=-R*Ts/log(a)`。拒绝不足样本、稳态DC共线、非正R/L、可见转动、周期/版本不一致。速度门槛只是输入约束，不能证明转子已锁止或反电势为零；需要外部证据。死区/器件压降、未执行电压及电流噪声都可能使模型失配。

正式PI为先积分更新 `I[k+1]=I[k]+Ki*Ts*e[k]`，本次候选电压 `u[k]=Kp*e[k]+I[k+1]`。令期望离散极点 `p_c=exp(-2*pi*fc*Ts)`、`g=1-p_c`，则：

```text
Kp = a*g/b
Ki = (1-a)*g/(b*Ts)
omega_cross = 2*asin(g/2)/Ts
PM = pi/2 - omega_cross*(Ts/2 + extraDelayS)
```

该模型已包含对象一拍输入作用 `z^-1` 与ZOH；`extraDelayS` 只填写额外计算/执行延迟。输入 `bandwidthHz` 是期望指数极点的连续等效频率，不是实测闭环带宽。工具按实际保存的float Kp及正式PI使用的float `Ki*Ts`复检二阶闭环Jury条件，再解析求量化后开环的交越频率与PM；上式是未量化理想值。极点舍入成1、积分步长下溢、`fc*Ts>=0.1`或预测PM不足45°均拒绝。它们是当前方法的明确准入规则，不是对所有离散控制器的普适定理。`mc_pi_cfg` 保持切换瞬间同一误差下 `Kp*e+I` 连续；之后新Ki会按新速率积分。积分超界或切到Ki=0无法无扰时明确拒绝。

MTPA在固定 `I=sqrt(id²+iq²)` 下最大化转矩。记 `delta=Lq-Ld>=0`，有：`id=-2*delta*I²/(psi+sqrt(psi²+8*delta²*I²))`，`iq=direction*sqrt(I²-id²)`。此消差形式在 `Ld=Lq` 时直接得到id=0。约束计算包含R压降，不能把电流圆上的MTPA候选自动当作高速可执行点。

DOB约定 `J*domega/dt=torque_applied-disturbance`；差分区间对应同区间已执行转矩，再用 `alpha=1-exp(-bandwidth*Ts)` 更新并限幅。PLL依次 `e=wrap(theta_measured[k]-theta[k])`、`omega[k+1]=clamp(omega[k]+Ki*Ts*e)`、`theta[k+1]=wrap(theta[k]+Ts*(omega[k+1]+Kp*e))`，以此真实更新顺序及最终保存的float增益做Jury检验；double设计通过不代表量化后仍稳定。

五次轨迹用 `s(u)=10u³-15u⁴+6u⁵`。其速度、加速度、jerk绝对峰值系数分别为 `1.875`、`10/sqrt(3)`、`60`，规划器按三个约束求持续时间并向上取整到Ts。起终点jerk可发生有界跳变，不能将此称为jerk连续的高阶轨迹。

## 单、双、三电阻接入

普通Butterworth二阶低通优先直接复用既有 `filter/巴特沃兹二阶滤波器` 的 `MotorBwLpf2_*`，不要借本模块重写一份LPF。`mc_filter` 为notch等通用系数保留DF-I、4状态、double中间值与错误不更新语义；旧LPF是TDF-II、2状态、float与未配置时旁路，两者执行职责有重叠，但不能无测试交换状态/失败策略或声称数值等价。目标工程已有合格滤波/PI执行器时先适配和验证，不能仅因本库存在就替换。

双/三电阻先把放大器极性、offset和比例校准到统一的相电流正方向，再填写有效掩码。3相有效时保留三相实测，只检查零和残差；2相有效时仅对缺失相执行 `Ia+Ib+Ic=0`。存在中性线电流、漏电、共模瞬态或不同采样时刻时，零和假设必须另行评审。

单电阻输入是实际S/H时刻、稳定窗口和上管导通向量，关系为 `iDC=sA*Ia+sB*Ib+sC*Ic`。消去Ic后只有固定2×2方程。同向量、互补向量及零矢量都不能恢复两自由度；函数拒绝而非返回虚假零电流。两个样本不同时，使用有证据支持的 `maxPhaseSlopeAS` 计算 `maxPhaseSlopeAS*(age1+age2)` 保守误差界，超限拒绝；这个界不是实测误差。`slopeBoundValid` 默认false会返回证据不足，不会把缺失的斜率界默认为电流恒定。死区期间上下管状态不确定、ADC/运放饱和或保护动作时应置 `valid=false`。

实机需测出开关到电流放大器稳定、ADC S/H、最小有源矢量保持、过调制和扇区边界退化。只满足代数秩并不意味着能在所需PWM周期获得有效两次采样。

## 独立真值、组合实验与诊断

测试不通过被测函数生成期望值：dq/PI/RL使用60~65位Decimal解析计算，RL使用独立ZOH真值与独立留出集；MTPA再用角度网格验证最优性；轨迹用独立Bernstein形式验证；FRF幅相来自独立信号合成；单电阻电流从真实相量与36组开关向量对独立生成。

组合实验直接调用正式Clarke/Park、PI候选/跟踪、dq前馈、逆Park与SVPWM，按实际duty重建电压，再由独立RK4 PMSM模型推进；电压在alpha-beta坐标内保持，电角度在区间内继续转动。包含正反转、母线下降、限流、饱和、参数±20%失配及恢复。它证明这一明确离散模型的宿主行为；未模拟ADC模拟前端、PWM死区、母线纹波、机械负载、目标中断和功率级保护。

| 失败表现 | 可重复区分实验 |
|---|---|
| 高速dq串扰/反向异常 | 先用固定电流/正反omega校验前馈符号，再核电角速度、锁存时间与实际执行电压；不能只改PI |
| RL结果跳变 | 看rankRatio、留出集误差、实际区间电压、转子速度与周期；DC稳态不能辨识L |
| 母线跌落后积分恢复慢 | 比较合成前馈后请求与最终可实现电压，确认回馈PI的是实际PI分量且不重复积分 |
| 编码器丢帧后角度跳变 | 检查物理锁存年龄、预测位移界与预测所有者；PLL角度属于k+1，不能再重复补一拍 |
| 单电阻扇区边界失真 | 分别检查有源矢量秩、实际稳定窗、采样时刻、时间差及电流斜率界，不能只查sector编号 |
| 三电阻零和异常 | 区分offset/增益/极性、采样不同步与真实共模/漏电；不要强行重构掩盖异常 |

目标构建、Target-in-the-Loop、硬件测量及WCET均是 `NOT_MEASURED`。宿主基准包含ctypes调用开销，只用于工具运行成本比较。高级磁链表/交叉饱和、完整无传感器观测器、MTPV/弱磁反馈、在线任意状态重规划、自动批量整定器、两惯量全闭环尚没有在本目录变成完整已验证实现，调用方不能将基础primitive覆盖解释为这些系统级能力全部完成。
