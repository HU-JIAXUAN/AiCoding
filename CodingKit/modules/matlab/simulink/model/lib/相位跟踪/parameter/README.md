# 参数与信号

## 配置参数

默认工况的可执行入口为[pll_test_parameters.m](pll_test_parameters.m)。控制参数继续使用本页所列M文件；修改默认值后执行`initialize_angle_tracking_test('AngleTrackingTest')`重新加载模型工作区，再运行模型。单次实验与全部模块入口见[参数使用索引](../../../../docs/guide/PARAMETER_USAGE.md).

默认定义：[angle_tracking_parameters.m](angle_tracking_parameters.m)。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts | 50e-6 | s | 离散更新周期与测试步长 |
| NaturalFrequency / Damping | 40 / 0.707 | Hz / 1 | 设计起点；不是实测闭环带宽 |
| Kp / Ki / Kaw | 355.38 / 63165.47 / 502.65，实际以函数为准 | 1/s、1/s²、1/s | 比例、积分与回算 |
| OmegaMax | 1500 | 电角 rad/s | 速度和积分状态界限 |
| MinMagnitude | 0.5 | 与 magnitude 相同 | 幅值资格门限 |
| LockError / LockSamples | 0.12 / 100 | rad / 样本 | 锁定误差和持续时间；默认 5 ms |
| Theta0 / Omega0 | 0 / 0 | rad / rad/s | 角度及积分状态初值 |

配置通过每个PLL库块的PLL configuration输入，默认表达式pllCfg；两个实例可分别填pllA/pllB。实例测试的完整配置由[initialize_pll_instances.m](../build_process/initialize_pll_instances.m)从本页默认函数产生，再覆盖Kp为100/250 1/s、Theta0为-0.2/0.3 rad、Ki和Kaw为0。该覆盖只用于隔离测试。

## 输入信号

| 名称 | 单位 | 类型或初值 | 来源/用途 |
|---|---|---|---|
| phase | 电角 rad | double，有限 | 待跟踪相位 |
| magnitude | 调用方声明 | double，非负 | 相位来源幅值；接 SMO 时为 V |
| enable / reset | 0/1 | double | 复位优先；禁能重置 |
| theta_true / omega_true | rad / rad/s | 测试记录列 | 不进入 PLL，仅比较 |

## 过程变量

| 名称 | 单位 | 类型或初值 | 所在块及计算 |
|---|---|---|---|
| theta_state | rad | Theta0 | Unit Delay，当前拍角度 |
| integral_state | rad/s | Omega0 | Unit Delay，PI 积分状态 |
| speed_raw / speed_limit | rad/s | double | 比例+积分及其限幅值 |
| limit_residual | rad/s | double | limited−raw，回算来源 |
| error_wrap | rad | double | atan2(sin(delta),cos(delta)) |
| count_state | 样本 | 0 | 连续资格计数，失效归零 |

## 输出信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| theta_e_hat | rad | double / Theta0 | k 时刻角状态，范围 [-π,π] |
| omega_e_hat | 电角 rad/s | double / 0 | 当拍 PI 限幅速度；幅值不足输出 0 |
| phase_error | rad | double / 0 | 包角相位误差；不可用时输出 0 |
| valid | 0/1 | double / 0 | 幅值/相位误差持续资格 |
| integral | rad/s | double / Omega0 | 积分状态诊断 |
| lock_count | 样本 | double / 0 | 当拍资格计数候选值 |

## Scope 通道

以下顺序已与R2026b实际模型连接核对；三组Scope各有一个向量输入端口，表中序号为向量元素顺序。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1 | phase | stimulus 第1列 | rad | 待跟踪相位 |
| AngleScope 2 | theta_e_hat | PLL 输出1 | rad | 估算角度 |
| AngleScope 3 | phase_error | PLL 输出3 | rad | 包角误差 |
| SpeedScope 1 | omega_true | stimulus 第6列 | rad/s | 独立真实速度 |
| SpeedScope 2 | omega_e_hat | PLL 输出2 | rad/s | 估算电角速度 |
| SpeedScope 3 | integral | PLL 输出5 | rad/s | 积分及限幅恢复 |
| StatusScope 1 | magnitude | stimulus 第2列 | 幅值 | 幅值失效 |
| StatusScope 2 | enable | stimulus 第3列 | 0/1 | 禁能 |
| StatusScope 3 | reset | stimulus 第4列 | 0/1 | 复位 |
| StatusScope 4 | valid | PLL 输出4 | 0/1 | 资格判据 |
| StatusScope 5 | lock_count | PLL 输出6 | 样本 | 连续资格持续时间 |

### AngleTrackingInstancesTest

两组Scope各一个向量输入；单位分开显示。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1 | theta_A | PLL_A输出1；trace列1 | rad / double | A实例角度状态 |
| AngleScope 2 | theta_B | PLL_B输出1；trace列3 | rad / double | B实例角度状态 |
| SpeedScope 1 | omega_A | PLL_A输出2；trace列2 | rad/s / double | A实例相位校正速度 |
| SpeedScope 2 | omega_B | PLL_B输出2；trace列4 | rad/s / double | B实例相位校正速度 |

该测试台输入为phase=0.1 rad、magnitude=1、enable=1、reset=0四个常量；没有接电机。4列trace的顺序与原12列测试台分开维护。

原AngleTrackingTest的trace 的 12 列依次为：phase、magnitude、enable、reset、theta_true、omega_true、theta_e_hat、omega_e_hat、phase_error、valid、integral、lock_count。布尔状态用 double 记录，不表示实际幅值。

## 原书符号与工程标识

符号与定义以[用户维护表](../../../../docs/userdocs/符号定义表.md)为准；以下只映射已有实现，不改写原表描述或单位。工程标识保持当前M文件/模型中的拼写。

| 原书符号 | 工程标识 | 工程单位 | 单位换算 |
|---|---|---|---|
| $T_s$ | cfg.Ts | s | 直接使用；各多速率周期分别配置 |
| $\omega_n$ | pllCfg.NaturalFrequency（工厂cfg.NaturalFrequency） | Hz | $\omega_n=2\pi\,NaturalFrequency$得到原书rad/s |

### 本模块局部量

本库是通用相位PLL：$\varphi_{in},\hat\varphi,\hat\Omega_{phase}$分别是输入相位、跟踪相位及其变化率，$\Omega_{req}$是未限幅PI请求。只有调用方已经构造转子电相位时，才将输出解释为$\hat\theta_r,\hat\omega_r$。$\omega_n$保留原表PLL固有频率rad/s的意义。
