# 两路位置融合：参数、状态与Scope

对应`SensorlessHandover/HybridFusion`和`src/HybridFusionTest.slx`，与原单向Handover分别配置。全部角度、速度为**电角量**，机械速度另除以极对数。实例通过Mask传入`fusionCfg`，状态互相独立。

## 配置参数

基础入口为[hybrid_fusion_parameters.m](hybrid_fusion_parameters.m)，修改后调用[refresh_hybrid_fusion_parameters.m](refresh_hybrid_fusion_parameters.m)。

| 名称 | 默认值 | 单位 | 用途 |
|---|---|---|---|
| Ts | 50e−6 | s | 融合与状态更新周期 |
| LowOmega / HighOmega | 40 / 60 | 电角rad/s | 速度幅值的加权重叠区，beta为基波权重 |
| LowMaxOmega / HighMinOmega | 80 / 30 | 电角rad/s | 本调用实例允许两路进入资格判断的速度范围 |
| MaxPhaseGap / MaxSpeedGap | .7 / 30 | 电角rad / 电角rad/s | 两路包角差和速度差门限，不能保证真实误差也小于此门限 |
| QualificationTime / QualificationSamples | .01 / 200 | s / 拍 | 首次连续合格时长及派生计数 |
| LossTime / LossSamples | .002 / 40 | s / 拍 | 已取得控制资格后无可用来源的最大预测窗口 |
| BlendTime | .05 | s | 正常双路合格时，beta每拍最多变化Ts/BlendTime |
| InjectionRampTime | .02 | s | 注入比例每拍最多变化Ts/InjectionRampTime |
| InjectionResumeOmega / InjectionOffOmega | 65 / 75 | 电角rad/s | 恢复/撤除注入的迟滞边界；撤除还要求beta=1及基波合格 |
| PhaseCorrectionRate | 20 | 电角rad/s | 相对基准旋转的附加相位修正率，上限每拍.001 rad |
| MaxPhaseInnovation | .2 | 电角rad | 每路相位相对该路上一安全相位、速度预测的突变门限 |
| MinInjectionScale | .1 | 1 | 低于此比例不接受HFI资格，并撤销旧低速分支锚定 |
| AllowHighStart | 1 | 0/1 | 基波独立合格且速度达到HighOmega时允许带速取得资格；整机需另验 |
| Vector / State0 | 17元素 / 20元素 | 混合 | 派生接口，不直接编辑；State0的注入比例与目标为1，其余为0 |

独立工况入口为[hybrid_fusion_test_parameters.m](hybrid_fusion_test_parameters.m)：1.3 s、初始电角.3 rad、速度20→100→20电角rad/s；.1–.5 s上升、.7–1.1 s下降；两路固定相位偏差−.03/+.02 rad，.85 s让低速候选角增加π，模拟停注入后返回另一轴线分支。此输入是独立逻辑夹具，不是电机测得响应。

## 输入信号

| 端口 / 刺激列 | 名称 | 单位/类型 | 来源与条件 |
|---|---|---|---|
| u1 / 1 | theta_low | 电角rad，double | 低速完整位置候选；首次启动前必须由上层完成磁极极性识别 |
| u2 / 2 | omega_low | 电角rad/s，double | 带符号低速估算速度 |
| u3 / 3 | low_valid | 0/1，double兼容 | 首次表示完整极性位置可用；不能直接接仅有π轴线资格 |
| u4 / 4 | theta_high | 电角rad，double | 独立基波观测器的完整位置 |
| u5 / 5 | omega_high | 电角rad/s，double | 带符号基波估算速度 |
| u6 / 6 | high_valid | 0/1，double兼容 | 基波自身幅值、方向和残差等资格 |
| u7 / 7 | enable | 0/1，double兼容 | 低时立即将输出和下一状态清零，注入状态恢复待启动值 |
| u8 / 8 | reset | 0/1，double兼容 | 高时优先复位，作用同禁能 |

测试刺激第9/10列为独立真实角度/电角速度，只用于Scope和离线评分，不接入库块。测试表以Ts逐行采样，FromWorkspace关闭插值。相位/速度/valid中非有限值使对应来源不合格；enable/reset非有限值触发故障2。

## 过程变量

状态全部在外置UnitDelay `States`，两个MATLAB Function均无persistent。

| 状态索引 | 名称 | 初值/单位 | 更新含义 |
|---|---|---|---|
| 1 / 2 | lastTheta / lastOmega | 0 / 电角rad、rad/s | 上一融合角与基准速度；无可用来源时短时预测 |
| 3 / 4 | beta / injection | 0 / 1 | 基波权重、HFI注入比例；injection初始1 |
| 5 | lowPiFlip | 0 / 0或1 | 低速候选额外加π的分支选择，不是重新进行磁饱和识别 |
| 6 / 7 | lowCount / highCount | 0 / 拍 | 首次资格连续累计；已合格来源短暂缺样时保留到LossSamples，但缺样本拍qualified仍为0 |
| 8 | lossCount | 0 / 拍 | 当前没有任何合格来源的连续拍数，达到LossSamples锁存退出 |
| 9 / 10 | acquired / fault | 0 / 标志、故障码 | 首次取得来源后保持；故障仅禁能/复位清除 |
| 11–14 | lastLowTheta/Omega、lastHighTheta/Omega | 0 / 电角rad、rad/s | 各自的安全预测，短时无效时继续推进相位，用于检查突跳 |
| 15 / 16 | lowSeen / highSeen | 0 / 标志 | 是否已有可用于创新检查的本路安全样本；持续失效后清除 |
| 17 | lowBranchReady | 0 / 标志 | 首次完整低速资格建立，或高速有效期间重新对齐π分支后建立；停止注入后清除 |
| 18 | injectionTarget | 1 / 0或1 | 迟滞目标，确保比例变化途中进入迟滞区也继续走向原目标 |
| 19 / 20 | lowBadAge / highBadAge | 0 / 拍 | 各路不合格持续时间，最多保留LossSamples |

正常双路合格时，`beta_target=clip((abs(omega)−LowOmega)/(HighOmega−LowOmega),0,1)`，候选角按`wrap(theta_low_aligned+beta*wrap(theta_high−theta_low_aligned))`混合。只有一条合格来源时，权重直接选该来源，最终相位仍经过附加修正率限制。

`omega_base`是用于物理速度控制的估算量；`omega_frame`是本拍融合角实际变化率，包含相位修正。后续App必须分别处理速度反馈、解耦和坐标状态跟踪，不能把相位修正速度当成真实加速。

## 输出信号

| 端口 / trace列 | 名称 | 单位 | 含义 |
|---|---|---|---|
| y1 / 11 | theta_e | 电角rad | 包角后的融合控制角 |
| y2 / 12 | omega_base | 电角rad/s | 两路估算速度的基准组合 |
| y3 / 13 | omega_frame | 电角rad/s | 融合角本拍实际变化率，首次取得资格时等于基准速度 |
| y4 / 14 | valid | 0/1 | 已取得来源且未超出预测窗口、未锁存故障 |
| y5 / 15 | beta | 0…1 | 基波权重；0低速、1基波 |
| y6 / 16 | injection_scale | 0…1 | 来自上一拍保持状态的注入比例，单独输出函数避免观测器代数环 |
| y7 / 17 | mode | 枚举 | 0等待、1低速、2混合、3基波、4故障 |
| y8 / 18 | fault | 枚举 | 0正常、1来源持续丢失、2enable/reset非有限 |
| y9 / 19 | low_qualified | 0/1 | 本拍低速可用，包括分支条件 |
| y10 / 20 | high_qualified | 0/1 | 本拍基波可用 |
| y11 / 21 | low_pi_flip | 0/1 | 对低速候选附加π的诊断 |
| y12 / 22 | phase_gap | 电角rad | 基波减去已对齐低速的包角差；无双路样本时0 |
| y13 / 23 | low_count | 拍 | 低速资格计数 |
| y14 / 24 | high_count | 拍 | 基波资格计数 |
| y15 / 25 | loss_count | 拍 | 融合来源缺失计数 |
| y16 / 26 | phase_correction | 电角rad/拍 | 本拍相对基准预测额外施加的相位修正 |
| y17 / 27 | low_branch_ready | 0/1 | 返回低速前是否已确认π分支 |

`trace`为27列double：前10列是测试输入，后17列按上表。时间在`out.trace.time`。故障1到达时valid立即为0，状态输出的注入比例最迟下一拍归零；enable/reset以及其非有限命令立即将注入输出归零。整机还需由最终使能门控功率级。

## Scope 通道

每个Scope一个向量输入，顺序如下，不把未连接变量登记为已有通道。

| Scope | 序号与来源 | 单位 / 观察内容 |
|---|---|---|
| AngleScope | 1 Inputs.y9真实角；2 Inputs.y1低速候选；3 Inputs.y4基波候选；4 Fusion.y1融合角 | 电角rad；包角与π分支 |
| AngleErrorScope | 1 AngleError（融合减真实的包角）；2 Fusion.y12两路相位差；3 Fusion.y16本拍附加修正 | 电角rad；误差、资格边界与过渡 |
| SpeedScope | 1 Inputs.y10真实速度；2 Inputs.y2低速估速；3 Inputs.y5基波估速；4 Fusion.y2基准速度；5 Fusion.y3坐标变化率 | 电角rad/s；估算与相位修正分开读 |
| WeightScope | 1 Fusion.y5基波权重；2 Fusion.y6注入比例；3 Fusion.y11附加π；4 Fusion.y17分支确认 | 1；加权、迟滞、注入恢复及分支 |
| StatusScope | 1 Inputs.y3低速valid；2 Inputs.y6基波valid；3 Fusion.y4融合valid；4 Fusion.y7模式；5 Fusion.y8故障；6 Fusion.y9低速合格；7 Fusion.y10基波合格 | 逻辑或枚举；来源资格与最终允许控制分别观察 |
| CountScope | 1 Fusion.y13低速计数；2 Fusion.y14基波计数；3 Fusion.y15来源缺失计数 | 拍；首次连续资格、短失效保持及超时 |

所有日志、Scope和状态更新均按fusionCfg.Ts。原单向Handover的22列日志及六组Scope继续见[README](README.md)。
