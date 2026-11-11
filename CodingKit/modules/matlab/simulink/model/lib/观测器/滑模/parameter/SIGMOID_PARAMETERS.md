# Sigmoid SMO参数、信号与Scope

## 配置参数

控制器入口为[sigmoid_smo_parameters.m](sigmoid_smo_parameters.m)，改Rs/L/Ts/K/Slope后执行[refresh_sigmoid_smo_parameters.m](refresh_sigmoid_smo_parameters.m)。[sigmoid_smo_pll_parameters.m](sigmoid_smo_pll_parameters.m)复用公共PLL工厂，并在本地同步Ts和最小幅值；可在此文件覆盖PLL增益及资格拍数，不必修改公共PLL默认值。测试工况全部在[sigmoid_smo_test_parameters.m](sigmoid_smo_test_parameters.m)。

| 名称 | 默认值 | 单位 | 含义 |
|---|---|---|---|
| Ts / Rs / L | 50e-6 / 0.5 / 1e-3 | s / Ω / H | 采样周期、每相电阻、SPMSM单电感 |
| Flux / PolePairs | 0.035 / 4 | Wb / 1 | Flux供独立电压轨迹使用；PolePairs是元数据，本测试不执行机械速度换算，二者不进入在线电流更新 |
| SlidingGain / Slope | 60 / 0.6 | V / A⁻¹ | 注入幅值上界与sigmoid指数斜率；零误差增益为两者乘积的一半 |
| MinEmf | 1 | V | 本地PLL工厂同步为MinMagnitude |
| MinOmega / MaxOmega | 30 / 800 | 电角rad/s | 资格允许的带符号方向速度范围；不是PLL数值限速 |
| MaxResidual | 2 | A | 同拍两轴估计减测量电流的范数上限 |
| MaxVoltage / MaxCurrent / MaxEstimate | 200 / 20 / 40 | V / A / A | 每个轴的输入电压、电流和预测电流数值范围 |
| A / B | exp(-Rs·Ts/L) / -expm1(-Rs·Ts/L)/Rs | 1 / A/V | 精确离散RL系数，由refresh计算 |
| MaximumInjectionSlope | 18 | V/A | SlidingGain·Slope/2，sigmoid最大导数 |
| LocalErrorPole | A-B·18，约0.086 | 1 | 零误差局部离散极点；refresh拒绝绝对值不小于1的配置 |
| Settings | 7×1 | 混合SI | 顺序为A、B、SlidingGain、Slope、MaxVoltage、MaxCurrent、MaxEstimate |
| pllCfg | 公共PLL默认增益、Theta0=0、LockError=0.12、LockSamples=100 | rad及对应SI | 本地PLL入口同步Ts/MinMagnitude；100拍在50µs下为5ms |

测试M入口中，Duration=0.3s、Omega=200rad/s、InitialTheta=0.4rad、Iq=2A，评价窗0.25–0.3s；HighOmega=600、低速5、越范围1000。加速为100rad/s起点、2000rad/s²、0.2s结束；Rs/L失配比例均1.2。电压噪声标准差0.02V，正常电流噪声0.005A，限制对照0.01A，Seed=23。复位0.15s起持续0.1ms，禁能0.1–0.15s；反转在0.1–0.2s由+300到-300rad/s；故障0.12s起。实例B为K=45、Slope=0.8、PLL初角1.1。对应字段均可直接修改M文件。

这些数值是合成MIL夹具。改Ts后，PLL资格时间随LockSamples·Ts改变；需要重新设计增益并核对数据采样，不只修改求解器步长。

## 输入信号

| 名称 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| u_alpha / u_beta，端口1/2 | V | double / 独立连续SPMSM电压 | 当前区间[kTs,(k+1)Ts)实际电压，只用于下一电流预测 |
| i_alpha / i_beta，端口3/4 | A | double / 独立连续SPMSM电流 | 当前采样电流，与当前先验电流相减 |
| direction，端口5 | -1/0/+1 | double / 已知方向 | 0撤销估计资格并复位；不从真实角度推算风车方向 |
| enable / reset，端口6/7 | 0/1 | double / 1、0 | 禁能或复位清状态及故障，reset优先 |

测试输入9列依次为上述7量及theta_true、omega_true。真值后两列只用于Scope和误差，不连接到SigmoidSMO。NaN/Inf电流在本拍产生故障1，电压异常在下一保持拍反映；非法方向/配置为故障2，非有限内部状态/预测为故障3。

## 过程变量

| 名称 | 单位/初值 | 所在块 | 计算或用途 |
|---|---|---|---|
| CurrentMemory(1:2) | A / 0 | Unit Delay | 本拍先验i_hat[k]，输出后才写下一状态 |
| CurrentMemory(3) | -1/0/+1 / 0 | 同上 | 上一方向，变化当拍清估计并复位PLL |
| CurrentMemory(4) | 故障码 / 0 | 同上 | 故障锁存到禁能/复位 |
| residual | A | Measure | i_hat-i_measured，逐轴电流误差 |
| injection | V | Measure | K·tanh(Slope·residual/2)，直接作为反电势近似，无显式EMF低通 |
| phase / magnitude | rad / V | Measure | 按方向处理的atan2相位与注入模长 |
| PLL角度/积分/连续计数 | rad、rad/s、拍 | 链接AngleTracking/PLL | 相位跟踪状态；资格不使用真实角度误差 |
| active / trackerReset | 0/1 | Measure | 方向、控制、状态和输入检查后的门控 |
| next current | A | Predict | A·i_hat+B·(u-injection)，只写下一拍 |

PLL在幅值足够、相位误差不超过0.12rad等条件持续100拍后取得其相位资格；本模块valid还要求Active、方向速度处于30–800rad/s及电流残差不超过2A。PLL速度限幅仍是其独立参数。

## 输出信号

| 名称/端口 | 单位 | 类型/初值 | 来源及用途 |
|---|---|---|---|
| theta_e_hat / 1 | 电角rad | double / PLL.Theta0 | 当前PLL角度，不是下一拍角度 |
| omega_e_hat / 2 | 电角rad/s | double / 0 | PLL估速；未取得资格前可有启动瞬态 |
| valid / 3 | 0/1 | double / 0 | 上述条件的在线资格，不是全工况正确性证明 |
| emf_alpha / emf_beta / 4、5 | V | double / 0 | 直接sigmoid注入，没有独立滤波EMF状态 |
| i_hat_alpha / i_hat_beta / 6、7 | A | double / 0 | 当前先验电流，inactive时输出零 |
| residual_alpha / residual_beta / 8、9 | A | double / 0 | 当前电流估计减采样值 |
| phase_measured / 10 | rad | double / 0 | atan2(-direction·zα,direction·zβ) |
| emf_magnitude / 11 | V | double / 0 | hypot(zα,zβ) |
| phase_error / 12 | rad | double / 0 | PLL本拍包角误差 |
| fault / 13 | 0/1/2/3 | double / 0 | 正常、输入、配置/控制、数值异常 |
| residual_norm / 14 | A | double / 0 | hypot(residualα,residualβ) |

trace为N×24：1–9输入；10–23依次为上述14输出；24为wrap(theta_hat-theta_true)。故障输入案例的输入列可含NaN/Inf，10–24输出仍需有限并撤销资格。图中角度展开只用于展示，原始日志保留包角。

## Scope 通道

六个Scope各有一个向量输入端口，下表序号是向量内顺序。所有日志/Scope按50µs更新。

| 序号 | 名称 | 来源 | 单位/记录类型 | 观察内容 |
|---|---|---|---|---|
| AngleScope 1/2/3/4 | theta_true / theta_hat / wrapped_error / phase_error | Inputs.y8 / Observer.y1 / AngleError / Observer.y12；trace8/10/24/21 | rad / double | 捕获、包角误差与PLL检测误差 |
| SpeedScope 1/2 | omega_true / omega_hat | Inputs.y9 / Observer.y2；trace9/11 | 电角rad/s / double | 带符号估速及启动瞬态 |
| EmfScope 1/2/3 | emf_alpha / emf_beta / magnitude | Observer.y4/y5/y11；trace13/14/20 | V / double | 平滑注入及幅值，不是显式低通输出 |
| CurrentScope 1/2/3/4 | i_alpha / i_hat_alpha / i_beta / i_hat_beta | Inputs.y3 / Observer.y6 / Inputs.y4 / Observer.y7；trace3/15/4/16 | A / double | 估计电流相对实测值的偏差 |
| ResidualScope 1/2/3 | residual_alpha / residual_beta / norm | Observer.y8/y9/y14；trace17/18/23 | A / double | 残差及资格门限 |
| StatusScope 1/2/3/4/5 | direction / enable / reset / valid / fault | Inputs.y5/y6/y7 / Observer.y3/y13；trace5/6/7/12/22 | 枚举或0/1 / double | 方向、清除和资格/故障时间 |

[运行与调参](../build_process/SIGMOID_USAGE.md) · [公式推导](../docs/公式推导.md) · [分析](../waveform_analysis/SIGMOID_ANALYSIS.md)
