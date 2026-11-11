# 运行物理混合闭环、调参和看波形

在R2026b中将当前目录切到本模块，交互时只打开当前模型：

```matlab
addpath('src','parameter','build_process','waveform_analysis');
open_system(fullfile('src','SensorlessHFIHybrid.slx'));
initialize_hfi_hybrid('SensorlessHFIHybrid');
out=sim(Simulink.SimulationInput('SensorlessHFIHybrid'));
```

默认.14 s请求25机械rad/s、按40 rad/s²爬升；.9 s加.02 N·m负载，1.4 s改请求8 rad/s，仿真到2.3 s。该工况先以HFI识别极性并起转，随后由EEMF接管，降速再恢复HFI。Scope通道和日志顺序见[参数页](../parameter/HYBRID_PARAMETERS.md)。

先查看FusionScope的权重、注入比例和两路资格，再看ValidityScope是否连续控制，最后比较SpeedScope、CurrentScope和TorqueScope。AngleScope同时记录两路候选及最终角；低速候选在高速暂停后可能位于相差π的分支，必须结合分支确认和最终融合误差判断。EMFResidualScope用于检查估计电流残差，不能只看EEMF输出是否有角度。

永久调整默认值，编辑[hfi_hybrid_app_parameters.m](../parameter/hfi_hybrid_app_parameters.m)及[hfi_hybrid_test_parameters.m](../parameter/hfi_hybrid_test_parameters.m)，然后重新初始化。一次试验用SimulationInput，不修改默认SLX：

```matlab
p=hfi_hybrid_app_parameters();
p.Test.SpeedReference=-25;
p.Test.ReturnSpeed=-8;
p.Test.LoadTorque=-.02;
values=hfi_hybrid_workspace(p);
in=Simulink.SimulationInput('SensorlessHFIHybrid');
fields=fieldnames(values);
for k=1:numel(fields)
    in=in.setVariable(fields{k},values.(fields{k}),'Workspace','SensorlessHFIHybrid');
end
in=in.setModelParameter('StopTime',num2str(p.Test.Duration,16));
out=sim(in);
```

改电机初始角时同步Motor.Position0并refresh物理参数；改Rs等观测器失配时仅覆盖EMF对应字段。改变周期需同步全部离散控制与观测配置，不能只改Ts一个值。上述默认方向先验为+1，方向保持状态会根据估算速度过零更新；没有把真实转速接入方向选择。

批量入口`run_hfi_hybrid_validation()`包含18个物理工况；选项如`run_hfi_hybrid_validation({'round_trip','high_gap_overlap'})`。完整调用写hybrid_results.mat/hybrid_metrics.json，选择工况写hybrid_subset_results.mat/hybrid_subset_metrics.json，避免把局部执行误写成完整通过。每项记录实际参数、输入和12份完整日志。脚本后台加载，结束后关闭模型。

第二个参数可选`'accelerator'`，例如`run_hfi_hybrid_validation([], 'accelerator')`运行全部工况，或传工况名称分批运行。普通与加速模式已在完整默认2.3 s工况比较12份日志；从原低速FOC重新搭建及正式目录各自再次核对。它是MIL仿真加速，不作为SIL或C2000执行证据。首次编译与每项执行耗时分别记录；GUI运行的仿真模式仍由模型工具栏选择。

读取原始标量日志时，`out.angle_error.signals.values`可能是`1×1×N`，可用`reshape(...,[],1)`转成N行；向量日志通常是`N×通道数`。验证入口统一转换成N行后保存，并检查日志中的角误差确实等于融合角减去对应时刻的真实角。

重建时使用工程副本，移走副本的SensorlessHFIHybrid.slx，保留原SensorlessHFIFOC及共用lib，再从副本调用build_hfi_hybrid。搭建脚本拒绝覆盖已有目标；旧位置启动和低速FOC模型继续保留。交互检查结束关闭Scope和模型，保留MATLAB主窗口。
