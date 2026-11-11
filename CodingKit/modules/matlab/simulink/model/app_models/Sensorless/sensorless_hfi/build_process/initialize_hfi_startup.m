function initialize_hfi_startup(model)
%INITIALIZE_HFI_STARTUP Load App-local composition and shared libraries.
module=fileparts(fileparts(mfilename('fullpath')));lib=fullfile(module,'..','..','..','lib');
addpath(fullfile(module,'src'),fullfile(module,'parameter'));
for dependency={'观测器/高频注入','相位跟踪','永磁同步电机','math'}
    addpath(fullfile(lib,dependency{1},'src'),fullfile(lib,dependency{1},'parameter'));
end
cfg=hfi_startup_app_parameters();workspace=get_param(model,'ModelWorkspace');
values=struct('hfiCfg',cfg.HFI,'pllCfg',cfg.PLL,'probeCfg',cfg.Probe,'polarityCfg',cfg.Polarity, ...
    'hfPlantCfg',cfg.Motor,'hfiStartupTestCfg',cfg.Test,'testStim',hfi_startup_stimulus(cfg.Test));
names=fieldnames(values);for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
end
