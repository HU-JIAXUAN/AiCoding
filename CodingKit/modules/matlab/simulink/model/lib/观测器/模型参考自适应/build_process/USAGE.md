# 运行、修改参数和查看MRAS波形

在R2026b中将当前目录切到本模块：

```matlab
addpath('src','parameter','build_process','waveform_analysis');
open_system(fullfile('src','MrasObserverTest.slx'));
initialize_mras_test('MrasObserverTest');
out=sim(Simulink.SimulationInput('MrasObserverTest'));
```

默认测试为600电角rad/s、真实初始角.7 rad，算法初始角0、速度先验300 rad/s。先看AngleScope和SpeedScope的捕获；再看CurrentModelScope的实测与一步预测电流，以及NormalizedScope、EmfScope和StatusScope的资格。具体顺序与日志列见[参数页](../parameter/README.md)。Scope按需打开，查看后关闭。

永久调参编辑[mras_parameters.m](../parameter/mras_parameters.m)或[mras_test_parameters.m](../parameter/mras_test_parameters.m)，停止仿真后重新初始化。改变PI设计频率、滤波或周期时调用refresh_mras_parameters同步派生量。当前是固定离散步长Ts的独立观测器测试。

一次试验使用SimulationInput，例如只改变估算电阻，保持输入的真实对象参数不变：

```matlab
cfg=mras_parameters();
cfg.Rs=.6;
cfg=refresh_mras_parameters(cfg);
in=Simulink.SimulationInput('MrasObserverTest');
in=in.setVariable('mrasCfg',cfg,'Workspace','MrasObserverTest');
out=sim(in);
```

修改真实对象或输入轨迹时，使用测试参数与mras_fixture重新生成testStim。方向先验必须随场景明确提供；0表示未知。不能把真实角度和速度接入库来帮助捕获。

批量验证入口为`run_mras_validation()`；选择工况如`run_mras_validation({'positive','negative','zero_speed'})`。完整调用保存results.mat/metrics.json，选项调用保存subset_results.mat/subset_metrics.json，不覆盖完整结果。记录含实际配置、真实对象参数、刺激表、评分窗口、26列波形与指标。模型在后台加载，结束后关闭。

```matlab
data=load('waveform_analysis/results.mat','records');
r=data.records.positive;
plot(r.time,r.trace(:,[8,10,26])); % 真实角、估算角、包角误差
```

波形中的预测/实测dq、残差、分母及资格诊断对应上一处理拍；当前输入电流为本拍，不能不对齐就相减。角度和速度则是本拍控制可使用的状态，valid为1后才有资格进入App。零速场景即使输出角度仍变化，只要valid为0就不能当作位置估算已经有效。

重建算法SLX需要从源码重新运行搭建脚本；已有目标会被拒绝覆盖。独立测试结束保存需要的修改，关闭当前Scope和模型，保留MATLAB主窗口。
