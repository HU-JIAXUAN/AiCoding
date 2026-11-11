function initialize_hfi_foc(model)
%INITIALIZE_HFI_FOC Load this App's configurations without clearing user state.
module=fileparts(fileparts(mfilename('fullpath')));lib=fullfile(module,'..','..','..','lib');
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
for dependency={'观测器/高频注入','相位跟踪','永磁同步电机','math','电流环','逆变器','速度环与位置环','MTPA弱磁','电压前馈'}
    addpath(fullfile(lib,dependency{1},'src'),fullfile(lib,dependency{1},'parameter'));
end
p=hfi_foc_app_parameters();workspace=get_param(model,'ModelWorkspace');
values=struct('hfiCfg',p.HFI,'pllCfg',p.PLL,'probeCfg',p.Probe,'polarityCfg',p.Polarity, ...
    'hfPlantCfg',p.Motor,'pmsmCfg',p.Motor,'hfiFocTestCfg',p.Test,'currentCfg',p.Current, ...
    'inverterCfg',p.Inverter,'feedforwardCfg',p.Feedforward,'motionCfg',p.Motion, ...
    'focCfg',p.FOC,'profileCfg',p.Profile,'refCfg',p.Reference,'testStim',hfi_foc_stimulus(p.Test));
names=fieldnames(values);for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
end
