# UKF库模型的搭建与各部分作用

本模块与EKF使用同一SPMSM四状态[iα,iβ,ωe,θe]和电流测量。主要书籍12.4提供过程方程；UKF的sigma点与权重另参考[官方算法](https://www.mathworks.com/help/control/ug/extended-and-unscented-kalman-filter-algorithms-for-online-state-estimation.html)。本实现使用显式协方差，没有使用平方根UKF名称。

## 1. 先固定校正与预测的时刻

UkfObserver库导出UKF子系统。它有七输入uα、uβ、iα、iβ、direction、enable、reset，25输出与EKF接口相同。PriorMemory为28元素UnitDelay，保存本拍先验x/P及资格历史。

Measurement通过库链接引用EkfObserver/KalmanMeasurement。它读取本拍电流，先校正先验，产生本拍后验角度、速度、P和诊断。当前电压只进入Predict，计算下一拍先验，再写入PriorMemory。因此控制器使用本拍后验角度时，没有当前电压到当前角度的直接馈通。

测量函数只是取前两个电流状态，H=[1 0 0 0;0 1 0 0]，所以线性Kalman校正与测量UT等价；共用Joseph协方差更新。UKF与EKF分别持有自己的状态，不共享积分/协方差内存。

## 2. 从后验协方差生成9点

[ukf_predict.m](../src/ukf_predict.m)先把P按StateScales归一化并对称化，再做Cholesky。令n=4、c=Alpha²·(n+Kappa)，sigma点为中心x和x±sqrt(c)·L的四列，共9点；物理L由归一化Cholesky因子乘回状态尺度得到。

均值权重wm0=1−n/c，其余wi=1/(2c)；中央协方差权重wc0=wm0+1−Alpha²+Beta。默认Alpha=1、Beta=2、Kappa=0，对应wm0=0、wc0=2、其余1/8。Alpha改变点的距离，也会改变权重，不能只缩放点而保留旧权重。

## 3. 每个点经过相同电机过程

9点分别调用[pmsm_sensorless_step.m](../../../永磁同步电机/src/pmsm_sensorless_step.m)的状态输出。当前u在本周期保持；电流采用Euler，速度在单周期近似恒定，θ增加Ts·ω后包角。加速度与模型不确定性通过Q表示；本模块不使用过程Jacobian传播协方差。

三个非角状态按均值权重求和；θ用加权sin/cos合成后atan2得到圆周均值。对各点减均值时，θ差也包角，再按协方差权重累加外积，最后加Q并对称化。默认过程P0/Q/R为对角配置；更新中的P为完整4×4矩阵，交叉项保留。

## 4. 数值与角分布边界

圆周统计仍是单峰局部高斯近似。生成点的θ偏移超过MaximumSigmaAngleDeviation时拒绝；圆周合成幅值小于MinimumAngleResultant时也拒绝，不把歧义角分布强行压成一个估计角。默认最大点偏移π/2−.001 rad，初始θ标准差.5 rad生成的±1 rad位于范围内。

Cholesky失败时，在归一化P上最多尝试5次对角jitter，从1e−12按10倍增加，且不超过1e−8。下一拍预测P也做完整分解检查。成功修复会累计numeric_repairs，每拍最多2个接受的修复事件；不能修复则故障3。该修复只处理规定范围内的数值问题，不代替正确的P0/Q/R。

输入电压异常为故障1，UT配置异常为2，数值/角分布异常为3。数值故障清状态并恢复配置P0，故障保持到禁能或复位。输入电流、方向、连续资格、NIS、角变化率与相反速度分支检查由共享Measurement执行；各条件见[参数页](../parameter/README.md)。Predict中的异常在下一保持拍显示；电流异常可在本拍撤销资格。

## 5. 把库接到验证模型

UkfObserverTest通过库链接调用UKF，FromWorkspace提供9列独立轨迹，其中真实θ/ω只用于对照。测试台保存24个标量输出、完整16元素P、9列输入及包角误差，共50列；10组Scope按实际顺序登记在参数页。没有给在线估计器接入真实位置或速度。

构建源为[build_ukf_observer.m](build_ukf_observer.m)。先创建Mask，再创建引用cfg.Model.Ts的端口；Mask默认ukf_parameters()，测试实例传ukfCfg，内层校正链接传同一cfg。库回调只设置自身和兄弟模块路径，测试模型回调再初始化本地参数和输入。

## 6. 区分源码、配置和结果

修改参数M后刷新并初始化，不用改SLX常数。修改ukf_predict算法M后，要在独立副本中重新构建，使SLX内嵌Function与M源一致；构建器遇到已有目标会停止，避免覆盖已有模型。普通运行现成SLX不需要调用model_edit；重建脚本使用MATLAB/Simulink Agent Toolkit的建模接口。

核对包含21项纯M数值检查、29项独立轨迹MIL及不同参数并行实例。官方对象在特定中央权重案例中的行为差异单独记录于[REFERENCE_BEHAVIOR.md](../waveform_analysis/REFERENCE_BEHAVIOR.md)，不为匹配该差异修改公开公式。运行与调参见[USAGE.md](USAGE.md)。
