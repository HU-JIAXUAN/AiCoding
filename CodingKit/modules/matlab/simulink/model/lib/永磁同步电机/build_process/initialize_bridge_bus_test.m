function initialize_bridge_bus_test(model)
%INITIALIZE_BRIDGE_BUS_TEST Read local executable defaults into workspace.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(module)));
if isfile(fullfile(project,'docs','scripts','initialize_motor_paths.m'))
    addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
end
addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
    fullfile(module,'build_process'),fullfile(module,'waveform_analysis'));
p=bridge_bus_test_parameters();workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'bridgeCfg',p.bridgeCfg);
assignin(workspace,'bridgeTestCfg',p.bridgeTestCfg);
assignin(workspace,'bridgeBusStim',bridge_bus_stimulus(p));
end
