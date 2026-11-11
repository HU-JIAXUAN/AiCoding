# 运行、改参数和观察波形

在R2026b中把当前目录切到本模块，然后执行：

```matlab
addpath('build_process');
open_system(fullfile(pwd,'src','HFIAxisTest.slx'));
initialize_hfi_test('HFIAxisTest');
out = sim('HFIAxisTest');
plot(out.trace.time,out.trace.signals.values(:,[7,14]));
legend('Plant electrical angle','Estimated axis');
```

模型的`PostLoadFcn`执行初始化，将参数加载到**模型工作区**。点击Run也使用同一套本模块`parameter/*.m`默认值。StopTime由`hfiTestCfg.Duration`决定；求解器ode4，步长`hfiTestCfg.PlantStep=Ts/20`；控制/采样50 μs。默认电机机械方程自由运动，没有人为加大惯量或阻尼。

修改默认配置可编辑[hfi_parameters.m](../parameter/hfi_parameters.m)、[hfi_test_parameters.m](../parameter/hfi_test_parameters.m)、[hfi_plant_parameters.m](../parameter/hfi_plant_parameters.m)，随后重新执行初始化。不要在点击Run之前再次初始化，否则会覆盖自己已经载入的临时参数。

只比较某个参数而不修改SLX时使用`SimulationInput`：

```matlab
addpath('parameter');
h = hfi_parameters();
h.InjectionVoltage = 4;
h = refresh_hfi_parameters(h);
p = hfi_pll_parameters(h); % 初始化函数已添加共用PLL参数路径
input = Simulink.SimulationInput('HFIAxisTest');
input = input.setVariable('hfiCfg',h,'Workspace','HFIAxisTest');
input = input.setVariable('pllCfg',p,'Workspace','HFIAxisTest');
out = sim(input);
```

改变采样周期时还必须同步`hfiTestCfg.Ts/PlantStep`及重新生成`hfi_stimulus`，保持激励表、电机求解和控制周期一致；改变初始角、饱和、交叉电感等物理夹具参数后，用`hfi_plant_parameters`重新构造`hfPlantCfg`。

先看`AxisScope`的π等价轴误差和完整角误差，再看`QualityScope`中的轴资格/响应资格。轴线收敛而完整角相差π是预期情况。`ResponseScope`显示逆电感量及电压差；`ADCScope`显示三相ADC及零序；`CalibrationScope`依次比较名义、外部、实际采用的逆电感均值；详细顺序见[Scope表](../parameter/README.md#scope-通道)。数值分析用`out.trace`的38列，原37列不变，最后一列是实际采用均值。

启用外部均值时，把`h.UseMeasuredInverseAverage=1`后refresh，并将`hfiTestCfg.ExternalInverseAverage`设为实测1/H值，同时通过SimulationInput覆盖`hfiCfg`和`hfiTestCfg`。默认0关闭该输入；外部值非有限、非正或尚未获得时不输出解调资格。完整探针/轴线/极性组合见[SensorlessHFIStartup](../../../../app_models/Sensorless/sensorless_hfi/README.md)。

完整独立验证及绘图：

```matlab
addpath('waveform_analysis');
report = run_hfi_axis_validation();
plot_hfi_axis_results();
```

验证用单次`SimulationInput`覆盖，不改模型默认参数。结果写入本模块`waveform_analysis`。批量脚本后台加载并在结束后关闭本测试模型；交互操作只打开当前Scope，用完关闭模型。此测试台包含物理电流响应，但不包含PWM开关、器件死区、真实ADC采样窗口或C2000执行耗时；后续App在已有逆变器/时序/死区积木上组合验证。
