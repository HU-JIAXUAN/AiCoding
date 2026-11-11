function initialize_handover_test(model)
%INITIALIZE_HANDOVER_TEST Synthetic phase inputs, not a closed-loop motor test.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
handoverCfg=handover_parameters();handoverTestCfg=handover_test_parameters();
sample=(0:round(handoverTestCfg.Duration/handoverCfg.Ts))';time=sample*handoverCfg.Ts;
theta=handoverTestCfg.InitialAngle+handoverTestCfg.ElectricalSpeed*time;wrap=@(x)atan2(sin(x),cos(x));
one=ones(size(time));
testStim.time=time;testStim.signals.values=[wrap(theta+handoverTestCfg.StartupAngleOffset), ...
    handoverTestCfg.ElectricalSpeed*one,handoverTestCfg.Ready*one,handoverTestCfg.StartupMode*one, ...
    handoverTestCfg.StartupFault*one,wrap(theta),handoverTestCfg.ElectricalSpeed*one, ...
    double(sample>=round(handoverTestCfg.ObserverValidTime/handoverCfg.Ts)), ...
    handoverTestCfg.ResidualNorm*one,handoverTestCfg.Enable*one,handoverTestCfg.Reset*one];
testStim.signals.dimensions=11;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'handoverCfg',handoverCfg);assignin(workspace,'testStim',testStim);
assignin(workspace,'handoverTestCfg',handoverTestCfg);
end
