# 捕获、过渡与退出的实现

1. 库的11个输入经Mux进入SequenceStep，Unit Delay显式保存九个状态，函数输出下一拍状态及本拍11个输出。没有persistent状态或Plant真值输入。
2. mode=0关闭；1使用软件角度；2累计捕获资格；3混合；4估算闭环；5锁存故障。enable=0或reset=1立即输出run=0并清状态，角度返回调用方theta_start。首次使能先经过一拍mode=0。
3. 普通捕获同时要求ready、observer_valid、电角速度下限、电流残差上限，以及软件/估算角速度差和包角相位差合格，连续CaptureSamples拍后进入混合；中间失败计数清零。软件启动模块的mode=1为零电流捕获窗口，此时允许不满足软件角/速度差，仍要求观测器有效、速度和残差合格。
4. 第一拍混合重新计算delta=wrap(theta_start-theta_hat_safe)，保证此拍控制角与启动角相同。令r=blend_count/BlendSamples，beta=r²(3-2r)，输出theta_used=wrap(theta_hat_safe+(1-beta)delta)。相位差用atan2(sin(x),cos(x))包角，不能对跨±π角度直接作普通平均。
5. omega_base是正常转动的基准角速度，混合/闭环时来自安全观测速度；omega_frame是下一采样区间的规划坐标转速，等于omega_base-delta·(beta_next-beta)/Ts。它包含坐标过渡修正，不能代替真实机械速度。该关系在恒速合成输入中已逐拍核对，观测相位噪声仍可带来下一拍修正。
6. 混合及闭环时，用上一拍安全相位和速度预测本拍相位。若valid、速度、残差或相位创新不合格，则短时沿预测相位前进，保持过渡计数；持续LossSamples拍后进入故障2、run=0。预测只是有界失效窗口内的延续，不表示观测仍有效。首个故障锁存；startup_fault在接管前触发故障1，内部非法模式触发故障3。
7. beta达到1后的下一拍进入mode=4/acquired=1；App将acquired延迟一拍送Startup。切换后的startup_fault不再参与退出，避免已完成使命的启动器超时干扰闭环。观测器失效仍独立退出。

库的Mask按实例传入handoverCfg。块和连线通过model_edit搭建，函数代码由公开MATLABFunctionConfiguration.FunctionScript导入，model_read回读、model_check检查。算法源位于src，构建脚本没有用set_param/add_block绕过编辑工具。

本模块没有电流PI。App还必须旋转启动电流参考，并在坐标变化时跟踪PI的积分、比例和前馈电压状态；仅检查角度过渡不能证明电流与转矩平顺。
