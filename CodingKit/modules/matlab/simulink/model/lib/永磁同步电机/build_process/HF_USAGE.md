# 高频物理对象的运行与调参

从simulink工程根目录运行：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
open_system('PMSMHighFrequencyPlantTest');
out=sim('PMSMHighFrequencyPlantTest');
plot(out.trace.time,out.trace.signals.values(:,[9,10]));
legend('id','iq'); ylabel('current A'); grid on;
```

GUI可直接点击Run，再打开HfCurrents、HfAngle、HfSpeed、HfTorque、HfFlux或HfInductance。通道顺序与数据列见[HF_PARAMETERS.md](../parameter/HF_PARAMETERS.md)。

## 修改M文件并刷新

电机参数入口为[pmsm_hf_parameters.m](../parameter/pmsm_hf_parameters.m)，它先读取原有pmsm_parameters，再覆盖本对象所需的Lq、饱和和交叉电感字段。测试脉冲和求解步长在[hf_plant_test_parameters.m](../parameter/hf_plant_test_parameters.m)。编辑后执行：

```matlab
initialize_hf_plant_test('PMSMHighFrequencyPlantTest');
out=sim('PMSMHighFrequencyPlantTest');
```

修改派生结构体时调用refresh_pmsm_hf_parameters；它校验增量电感正定性，并生成Settings和InitialState。仅改变某个字段而不刷新，会保留旧的派生向量。

## 单次覆盖示例

```matlab
plant=pmsm_hf_parameters();
plant.SaturationDepth=0;       % 线性磁路的正负脉冲对照
plant.MechanicalEnabled=0;    % 明确使用理想锁轴夹具
plant=refresh_pmsm_hf_parameters(plant);
input=Simulink.SimulationInput('PMSMHighFrequencyPlantTest');
input=input.setVariable('hfPlantCfg',plant,'Workspace','PMSMHighFrequencyPlantTest');
out=sim(input);
```

修改测试时长、脉冲方向/宽度、负载或采样周期时，另用hf_plant_stimulus生成新输入；求解步长也按本次配置显式覆盖：

```matlab
test=hf_plant_test_parameters();
test.VoltageAxis=pi/4;
input=input.setVariable('hfPlantTestCfg',test,'Workspace','PMSMHighFrequencyPlantTest');
input=input.setVariable('testStim',hf_plant_stimulus(test),'Workspace','PMSMHighFrequencyPlantTest');
input=input.setModelParameter('StopTime',num2str(test.Duration,16), ...
    'FixedStep',num2str(test.PlantStep,16));
out=sim(input);
```

单次SimulationInput覆盖不会把实验值存回源SLX；批量验证中每个工况也保存实际参数。

## 完整验证与读取

```matlab
addpath(fullfile(pwd,'model','lib','永磁同步电机','waveform_analysis'));
report=run_hf_plant_validation();
folder=fullfile(pwd,'model','lib','永磁同步电机','waveform_analysis');
data=load(fullfile(folder,'hf_results.mat'));
r=data.records.free_rotor;
plot(r.time,r.trace(:,[6,7])); grid on;
```

验证脚本覆盖14个物理对象工况，并检查磁链Jacobian。重跑更新hf_results.mat、hf_metrics.json和带hf_前缀的波形，失败时保存hf_failure.mat。原线性对象的results.mat和metrics.json另行保留。

[搭建与方程](HF_BUILD.md) · [模块入口](../README.md)
