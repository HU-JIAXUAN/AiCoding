function initialize_hfi_probe_test(model)
%INITIALIZE_HFI_PROBE_TEST Load this module's orthogonal-probe physical fixture.
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
    fullfile(lib,'永磁同步电机','src'),fullfile(lib,'永磁同步电机','parameter'),fullfile(lib,'math','src'));
probeCfg=hfi_probe_parameters();hfiTestCfg=hfi_probe_test_parameters();
hfPlantCfg=hfi_plant_parameters(hfiTestCfg);testStim=hfi_stimulus(hfiTestCfg);
workspace=get_param(model,'ModelWorkspace');values=struct('probeCfg',probeCfg,'hfiTestCfg',hfiTestCfg, ...
    'hfPlantCfg',hfPlantCfg,'testStim',testStim);names=fieldnames(values);
for k=1:numel(names),assignin(workspace,names{k},values.(names{k}));end
end
