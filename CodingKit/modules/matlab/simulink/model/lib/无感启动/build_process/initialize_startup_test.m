function initialize_startup_test(model)
%INITIALIZE_STARTUP_TEST Install local defaults; no base-workspace variables.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
startupCfg=startup_parameters();startupTestCfg=startup_test_parameters();
time=(0:round(startupTestCfg.Duration/startupCfg.Ts))'*startupCfg.Ts;
testStim.time=time;
testStim.signals.values=repmat([startupTestCfg.Enable,startupTestCfg.Reset,startupTestCfg.Direction,startupTestCfg.Acquired],numel(time),1);
testStim.signals.dimensions=4;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'startupCfg',startupCfg);assignin(workspace,'testStim',testStim);
assignin(workspace,'startupTestCfg',startupTestCfg);
end
