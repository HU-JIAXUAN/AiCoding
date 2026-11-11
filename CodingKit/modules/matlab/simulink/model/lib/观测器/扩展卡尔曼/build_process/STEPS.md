# EKF四状态、协方差和时序的搭建

主参考为书12.4.1–12.4.3，印刷315–317/PDF344–346。状态顺序固定为[iα,iβ,ωe,θe]，电流测量为前两个状态，电压为αβ实际作用电压。SPMSM单L、每个采样区间近似恒速；未知加速度由配置的过程噪声表示。

## 过程和测量共用

[pmsm_sensorless_step.m](../../../永磁同步电机/src/pmsm_sensorless_step.m)给出Euler过程及解析Jacobian，[pmsm_sensorless_measurement.m](../../../永磁同步电机/src/pmsm_sensorless_measurement.m)给出电流映射H。EKF与后续UKF使用同一过程/测量定义，原PMSMPlant及其IPMSM默认值保持原定义。

```text
i_alpha_next = i_alpha + Ts/L·(u_alpha − Rs·i_alpha + omega·Flux·sin(theta))
i_beta_next  = i_beta  + Ts/L·(u_beta  − Rs·i_beta  − omega·Flux·cos(theta))
omega_next   = omega
theta_next   = wrap(theta + Ts·omega)
```

Jacobian为对该离散过程的状态偏导，角度包角按局部切线处理。共用过程另外用正反向、零速和跨π选点的中心差分核对；它不是电机机械闭环仿真。

## 本拍先校正，当前电压只用于下一拍

UnitDelay保存到当前时刻的先验x/P和资格历史。KalmanMeasurement读取当前采样电流，计算innovation=i_measured−H·x_prior及S=H·P_prior·Hᵀ+R，再通过K=P_prior·Hᵀ/S校正状态。避免显式求逆；该测量协方差为2×2。

后验P采用Joseph形式`(I−KH)·P_prior·(I−KH)ᵀ+K·R·Kᵀ`并对称化。当前θ/ω即来自后验；速度、相位及协方差都可记录。EKF的Predict块消费本拍后验和本拍电压，计算下一拍先验`P_next=A·P_post·Aᵀ+Q`，写入UnitDelay。当前电压不进入本拍Measurement，因此电流控制器使用后验角时不会形成电压→估角→电压的代数环。

共用KalmanMeasurement在EkfObserver库独立导出，仅负责固定线性电流测量校正及资格；后续UKF引用同一库链接，替换过程预测算法。共用块没有自己的保持状态，完整观测器的28元素UnitDelay分别属于各个实例。

## 28个保持量

| 索引 | 变量 | 单位/作用 |
|---|---|---|
| 1–4 | 当前先验状态 | A、A、rad/s、rad |
| 5–20 | 4×4先验P按列展开 | Pij的单位为state_i单位×state_j单位 |
| 21 | 连续资格计数 | 拍 |
| 22–24 | 上一后验角、低通角变化率、角历史有效 | rad、rad/s、0/1 |
| 25–27 | 上一方向、故障、已初始化 | −1/0/+1、枚举、0/1 |
| 28 | 数值修复计数 | EKF为0，UKF共用诊断接口使用 |

本拍posterior_memory暂存同样布局的后验x/P，Predict只替换其中前20项为下一拍先验，资格历史随之保持。没有persistent，也没有对象真实θ/ω输入。

## 资格、相反速度分支与复位

书中指出估速可能收敛到相反数。除方向先验、最低速度/反电势、NIS和σ限制外，本实现对相邻后验角包角差分并低通，与估算ω比较。小电流创新或小配置协方差单独不足以放行。另有合成反例：NIS=0、σ很小、估速−600且方向先验−1，但估算角历史变化率+600；保持该门限时valid为0，放宽门限后会放行。

direction=0只禁止资格，继续预测/校正；正常方向变化清连续计数并保留位置状态，便于跨零后重新取得资格。禁能/复位清状态并恢复P0；再次启用按方向先验设初速。数据异常/数值范围为故障1，控制或配置无效为2，增益/协方差数值异常或估速越界为3；故障需禁能/复位清除。电流异常可在本拍撤销资格，电压异常在下一保持拍反映。

Q由状态方差密度乘Ts得到，R由每次电流测量标准差平方得到，P0由初始标准差平方得到。它们的单位和统计角色不同。σ是当前模型/Q/R配置给出的不确定度，实际偏差仍需用独立数据评估。

## 创建与重建

[build_ekf_observer.m](build_ekf_observer.m)先创建Mask，再创建cfg.Model.Ts端口；先保存共用校正块，再在同一库通过链接组装EKF。库加载回调只添加本模块及共用过程路径；测试台回调另加载工作区参数与输入。

源码M改变需要重新构建SLX内嵌MATLAB Function；参数M改变后重新初始化即可。重建使用独立的observer_ekf/pmsm_plant兄弟目录副本，移走副本的两个EKF SLX再运行搭建脚本，禁止覆盖原模型。批量运行不打开编辑器或Scope。
