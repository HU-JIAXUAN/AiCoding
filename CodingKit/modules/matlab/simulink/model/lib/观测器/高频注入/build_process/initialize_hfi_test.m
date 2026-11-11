function initialize_hfi_test(model)
%INITIALIZE_HFI_TEST Load local configuration and linked library dependencies.
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
    fullfile(lib,'相位跟踪','src'),fullfile(lib,'相位跟踪','parameter'), ...
    fullfile(lib,'永磁同步电机','src'),fullfile(lib,'永磁同步电机','parameter'), ...
    fullfile(lib,'math','src'));
hfiCfg=hfi_parameters();hfiTestCfg=hfi_test_parameters();
pllCfg=hfi_pll_parameters(hfiCfg);hfPlantCfg=hfi_plant_parameters(hfiTestCfg);
testStim=hfi_stimulus(hfiTestCfg);workspace=get_param(model,'ModelWorkspace');
values=struct('hfiCfg',hfiCfg,'hfiTestCfg',hfiTestCfg,'pllCfg',pllCfg, ...
    'hfPlantCfg',hfPlantCfg,'testStim',testStim);
names=fieldnames(values);
for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
end
