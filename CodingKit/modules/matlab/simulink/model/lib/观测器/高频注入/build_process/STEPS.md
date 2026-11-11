# HFI轴线模型的搭建过程

## 1. 先确定可观测量和限制

主要依据《永磁同步电机无位置传感器控制》4.2–4.3（印刷79–85页，PDF108–114页）的增量电感及脉振方波注入。当前实现是本工程的双区间差分解调，并非书中框图逐块复制。位置跟踪复用`AngleTracking/PLL`。HFIAxis自身确定到π；现已补同库[极性块](POLARITY_BUILD.md)及[启动App](../../../../app_models/Sensorless/sensorless_hfi/README.md)，同模块[低速FOC](../../../../app_models/Sensorless/sensorless_hfi/build_process/FOC_BUILD.md)已完成24项物理MIL；HFI/基波双向融合继续建设。

`HFIAxis`的7个输入是实际电压αβ、采样电流αβ、注入比例、enable、reset。没有真实角度输入。输出中`theta_axis`表示当前选中的连续轴线分支；真正完整电角度还需要极性信息。

## 2. 建立真实激励闭环

`CarrierState`每个采样翻转一次，周期为2Ts，默认10 kHz。`BoundedScale`把比例限到0–1，`Active`在禁能或复位时使请求为零。将载波、比例和5 V相乘，再乘估计轴的cos/sin得到αβ注入请求。

测试台把请求经过执行增益/可选一拍延迟后送入`PMSMHighFrequencyPlant/HFPMSM`。Plant积分电流、机械速度和角度，输出真实电流；这些电流转成三相，经过ADC偏置/噪声/限幅/量化，再用共用Clarke变换回αβ。真实θ只进入`AxisDifference`误差评估及记录。

## 3. 明确电压和电流的样本年龄

约定`i[k]`结束了`u[k−1]`的执行区间。`VoltageOld/Older`保存两段实际作用电压，`CurrentOld/Older`保存两个电流历史样本。当前`u[k]`仅进入电压记忆，不直接参与当前解调。

令前次注入单位轴为a，第二电流差分为Δ²i，电压差为Δu，则本工程使用：

```text
projection = dot(Δu, a)
response_ab = (i[k] − 2*i[k−1] + i[k−2]) / (Ts*projection)
response_dq = R(−axis[k−1])*response_ab
saliency = [response_d − inverse_average; response_q]
stationary_double = R(2*axis[k−1] − cross_phase)*saliency
filtered = a*filtered_previous + (1−a)*stationary_double
phase_double = atan2(filtered_beta,filtered_alpha)
```

其中`inverse_average=(Ld+Lq)/(2*(Ld*Lq−M²))`，`cross_phase=atan2(−2M,Lq−Ld)`。常值电流偏置可由第二差分抵消；噪声、量化、饱和及转动项仍会影响结果，不能理解为无条件抗干扰。

`voltage_step`记录有符号投影。电压差太小、横向电压变化过大或历史注入未建立时拒绝本拍。双角静止向量经过300 Hz一阶低通，避免直接滤包角造成±π跳变；极点为exp(−2π·Bandwidth·Ts)，状态由DemodFilter保存。响应幅值按`norm(filtered)*Ts*abs(projection)/2`换算为A，使用实际电压差，不用名义5 V冒充真实激励。滤波用于降低二阶差分放大的量化/噪声，带来的动态相位延迟须由实际低速工况验证，当前未额外补偿。

## 4. 双角PLL和连续轴线

凸极响应含2θ，所以PLL跟踪双电角度和双电角速度。直接把包角的PLL角度除以2会在±π处产生π跳变。`hfi_track_axis`保存上次轴线和双角，先求双角的包角增量、除2，再累积到轴线状态；速度除2。

`axis_valid`要求PLL锁定、响应门限通过且速度处于本模块设定范围。它不表示极性已识别，也不能独立证明电机有凸极性。平均电感设错的圆转子反例会明确记录在验证中。

## 5. 复位、禁能与暂停注入

reset或enable=0时，PLL回初值、轴线状态回`InitialAxis`，注入为零、载波复位为+1。电流/电压历史仍采样物理信号；历史比例在重新激励前连续两拍不足时不能解调，随后还要满足PLL锁定计数。

仅把`injection_scale`降为0时，请求为零且响应资格撤销，不清除轴线分支状态。极性脉冲阶段据此暂停HFI并保留轴线；PolarityPulse完成双脉冲后恢复注入，等待轴线重新锁定才给出完整位置资格。实测均值的新增输入及实际采用值输出见[校准/极性搭建](POLARITY_BUILD.md)。

## 6. 复现模型

[build_hfi_observer.m](build_hfi_observer.m)通过`model_edit`分作用域创建、连接、布局和检查；MATLAB Function公开`FunctionScript`接口写入[解调](../src/hfi_demodulate.m)、[轴线展开](../src/hfi_track_axis.m)和[ADC夹具](../src/hfi_measure_current.m)源码。脚本拒绝覆盖已有SLX，应在隔离副本中重建。

[运行方法](USAGE.md) · [参数/Scope](../parameter/README.md) · [书籍设计核对](../../../../../docs/references/BOOK_SENSORLESS_DESIGN.md)
