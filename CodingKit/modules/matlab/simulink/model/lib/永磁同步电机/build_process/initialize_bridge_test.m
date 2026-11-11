function initialize_bridge_test(model)
%INITIALIZE_BRIDGE_TEST Initialize the local physical bridge validation model.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(module)));
if isfile(fullfile(project,'docs','scripts','initialize_motor_paths.m'))
    addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
end
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'waveform_analysis'));
p=bridge_test_parameters();workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'bridgeCfg',p.bridgeCfg);assignin(workspace,'bridgeTestCfg',p.bridgeTestCfg);
assignin(workspace,'bridgeStim',bridge_plant_stimulus(p));
end
