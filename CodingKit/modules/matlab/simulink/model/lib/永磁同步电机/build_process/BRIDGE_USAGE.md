# 运行和修改桥耦合对象

在工程根目录使用R2026b：

```matlab
addpath(fullfile(pwd,'docs','scripts'));
initialize_motor_paths();
p = bridge_test_parameters();
r = run_bridge_case(p);
```

默认先80rad/s滑行，15ms进入主动短路，25ms释放，再运行至60ms。模型只在需要时隐藏加载，运行器关闭本次加载的模型，保留你已经加载的模型。r.parameters保存实际参数，r.trace/r.columns/r.definitions说明33列。

修改本次实验：

```matlab
p = bridge_test_parameters();
p.bridgeCfg.Speed0 = 120;
p.bridgeCfg.Vdc = 24;
p.bridgeTestCfg.ModeTimes = 0;
p.bridgeTestCfg.ModeValues = 0; % 全门极关断，仍允许二极管整流
p.bridgeTestCfg.Duration = 0.02;
r = run_bridge_case(p);        % 自动刷新Vector与State0
```

修改默认物理值用[pmsm_bridge_parameters.m](../parameter/pmsm_bridge_parameters.m)，修改默认验证实例用[bridge_test_parameters.m](../parameter/bridge_test_parameters.m)。手工更新模型工作区时，先执行refresh_pmsm_bridge_parameters；不要只改Rs而保留旧Vector。

界面运行：只打开src中的PMSMBridgePlantTest.slx，加载回调会初始化。改M文件后执行initialize_bridge_test('PMSMBridgePlantTest')再点击Run。查看库的内部连接可使用Mask的Look Under Mask；Step和Measure的可读源文件在src中。

完整验证入口run_bridge_validation()会覆盖本模块bridge_results.mat、bridge_metrics.json和三组图；run_bridge_kernel_checks()保存独立物理核对。重建使用build_pmsm_bridge_plant()，已有目标SLX时拒绝覆盖，须在独立副本重建。

记录中相电流属于当前状态；next_phase_current和区间等效电压属于离散推进区间。接观测器时必须设计区间电压的采样年龄，不把下一拍电流诊断接作反馈。真实theta_e是对象评估量，不能作为无位置控制反馈。

[Scope和列号](../parameter/BRIDGE_PARAMETERS.md) · [波形分析](../waveform_analysis/BRIDGE_ANALYSIS.md)
