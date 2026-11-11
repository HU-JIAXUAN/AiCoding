# 搭建过程

[build_emf_observer.m](build_emf_observer.m)已创建EmfObserver中的LinearEMF、EEMF两个导出块及两个独立测试台，均位于本模块src。[initialize_emf_test.m](initialize_emf_test.m)按测试模型选择SPMSM或IPMSM参数，[emf_fixture.m](emf_fixture.m)从独立dq电压平衡产生输入。过程为：创建端口和MATLAB Function → 嵌入M源码 → 连接状态、创新与PLL → 检查连接 → 添加实例配置Mask → 保存库 → 建立并编译两个测试台。

| 搭建图 | 内容 |
|---|---|
| [eemf_core_diagram.png](eemf_core_diagram.png) | 四状态、创新、方向和PLL连接 |
| [linear_test_diagram.png](linear_test_diagram.png) | SPMSM测试输入、误差及六组Scope |
| [eemf_test_diagram.png](eemf_test_diagram.png) | IPMSM测试台 |

## 状态和离散方法

令J=[0,-1;1,0]，创新r=i−i_hat。连续模型为：

```text
di_hat = (-Rs*i_hat + omega_hat*(Ld-Lq)*J*i_hat - e_hat + u)/Ld + l1*r
de_hat = omega_hat*J*e_hat + l2*r
l1 = 2*wo - Rs/Ld
l2 = -Ld*wo^2
wo = 2*pi*BandwidthHz
```

状态由UnitDelay保存，MATLAB Function只计算下一拍，前向Euler步长Ts。重复极点配置按ω=0模型推导；转动、参数误差和凸极条件下的实际收敛仍需测试，不把wo直接当作实测带宽。

扩展反电势幅值为`(Ld-Lq)*(omega*id-diq/dt)+omega*Flux`，方向为[-sin(theta);cos(theta)]；SPMSM时Ld=Lq，退化为普通反电势。该公式用于独立对象和结果解释，真实theta、omega和幅值不输入在线观测器。

PLL来自angle_tracking库，分别接入测量相位和反电势幅值。valid由PLL资格、运行许可、direction*omega_hat≥MinOmega及电流残差范数共同产生。禁能、复位或方向变化会清状态。两种观测器的配置和PLL结构体通过块Mask逐实例传入。

## 运行

从工程根目录运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'));initialize_motor_paths();
open_system('EemfObserverTest');
initialize_emf_test('EemfObserverTest');
out=sim('EemfObserverTest');
plot(out.trace.time,out.trace.signals.values(:,[9,11]));
```

查看SPMSM时使用`LinearEmfTest`。修改本模块parameter中的默认值后，重新执行对应初始化函数；参数位于模型工作区。Block Mask中的`emfCfg|pllCfg`分别连接观测器和PLL配置，可换成各实例独立的结构体名称。LinearEMF要求Ld=Lq；EEMF使用Ld和Lq两项。

单次修改估算电阻而保持测试输入不变：

```matlab
cfg=emf_parameters('ipmsm');cfg.Rs=0.6;
input=Simulink.SimulationInput('EemfObserverTest');
input=input.setVariable('emfCfg',cfg,'Workspace','EemfObserverTest');
out=sim(input);
```

对照实际对象电阻变化时，应通过emf_fixture重新计算输入电压，而不是同时修改估算和真实值后声称有参数失配。批量入口为waveform_analysis中的run_emf_validation，它保存每次实际参数、轨迹和22列记录。

构建脚本拒绝覆盖已有源模型；算法源码变更需在独立模块副本重建。仅修改src/emf_predict.m不会自动改写SLX内嵌MATLAB Function；本次正式重新加载已检查二者一致。

## 适用条件

当前独立测试使用Ld=1 mH，SPMSM的Lq=1 mH、IPMSM的Lq=1.2 mH。EEMF的旋转模型忽略幅值快速变化对应的扰动项；电流瞬态、极端参数及幅值过零需要另外验证。在线方向来自已知工况/起转方向；实际App的带速捕获和反转必须处理方向确认。独立轨迹测试不包含逆变器电压上限或电机机械起转，不计为已经接管的整机闭环。

[模块入口](../README.md)
