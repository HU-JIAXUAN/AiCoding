function p=extension_foc_parameters(kind)
%EXTENSION_FOC_PARAMETERS Common SPMSM/bridge fixture, local observer parameters.
spec=extension_foc_spec(kind);
entry=which('initialize_motor_paths');assert(~isempty(entry),'Initialize formal engineering paths first.');
root=fileparts(fileparts(fileparts(entry)));
fw=fullfile(root,'model','app_models','Sensorless','sensorless_fw');
addpath(fullfile(fw,'parameter'),fullfile(fw,'build_process'));
for name={'观测器/高频注入','观测器/模型参考自适应','观测器/扩展卡尔曼','观测器/无迹卡尔曼','观测器/滑模'}
    module=fullfile(root,'model','lib',name{1});
    addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
end
p=sensorless_fw_parameters();
p=rmfield(p,{'emfCfg','deadtimeCfg'});
p.experimentCfg=rmfield(p.experimentCfg,{'UseInverter','LogTs'});
p.focCfg=rmfield(p.focCfg,{'CurrentMax','Kt'});
p.motionCfg=struct('SpeedLimit',120,'AccelerationLimit',p.motionCfg.AccelerationLimit);
p.extensionCfg=struct('Kind',spec.kind);
p.pmsmCfg.Lq=p.pmsmCfg.Ld;
p.currentCfg=current_parameters(p.pmsmCfg);p.currentCfg.Ts=50e-6;p.currentCfg.Kaw=1/p.currentCfg.Ts;
p.focCfg.SpeedReference=80;
p.refCfg.MtpaEnable=0;p.refCfg.FwEnable=0;
p.startGuardCfg.MaxStartVoltage=p.startGuardCfg.MaxStartEmf;
p.startGuardCfg=rmfield(p.startGuardCfg,'MaxStartEmf');
switch spec.kind
    case 'mras'
        p.observerCfg=mras_parameters();
    case 'ekf'
        p.observerCfg=ekf_parameters();p.observerCfg.InitialOmega=0;
    case 'ukf'
        p.observerCfg=ukf_parameters();p.observerCfg.InitialOmega=0;
    case 'sigmoid'
        p.observerCfg=sigmoid_smo_parameters();p.pllCfg=sigmoid_smo_pll_parameters(p.observerCfg);
end
if ~strcmp(spec.kind,'sigmoid'),p=rmfield(p,'pllCfg');end
% Set matched nominal observer physics once. Refresh preserves explicit
% observer-only overrides so resistance/inductance mismatch remains testable.
if ismember(spec.kind,{'mras','sigmoid'})
    p.observerCfg.Ts=p.currentCfg.Ts;p.observerCfg.Rs=p.pmsmCfg.Rs;p.observerCfg.L=p.pmsmCfg.Ld;
    p.observerCfg.Flux=p.pmsmCfg.Flux;p.observerCfg.PolePairs=p.pmsmCfg.PolePairs;
else
    m=p.pmsmCfg;p.observerCfg.Model=struct('Ts',p.currentCfg.Ts,'Rs',m.Rs,'L',m.Ld,'Flux',m.Flux,'PolePairs',m.PolePairs);
end
p=refresh_extension_foc_parameters(p);
end
