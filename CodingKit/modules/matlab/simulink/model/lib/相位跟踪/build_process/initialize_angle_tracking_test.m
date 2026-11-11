function initialize_angle_tracking_test(model)
%INITIALIZE_ANGLE_TRACKING_TEST Install self-contained defaults in model workspace.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
pllCfg=angle_tracking_parameters();
pllTestCfg=pll_test_parameters();t=(0:round(pllTestCfg.Duration/pllCfg.Ts))'*pllCfg.Ts;
omega=pllTestCfg.ElectricalSpeed*ones(size(t));theta=pllTestCfg.InitialAngle+pllTestCfg.ElectricalSpeed*t;
u=[atan2(sin(theta),cos(theta)),pllTestCfg.Magnitude*ones(size(t)), ...
    pllTestCfg.Enable*ones(size(t)),pllTestCfg.Reset*ones(size(t)), ...
    atan2(sin(theta),cos(theta)),omega];
testStim.time=t; testStim.signals.values=u; testStim.signals.dimensions=6;
mw=get_param(model,'ModelWorkspace');
assignin(mw,'pllCfg',pllCfg); assignin(mw,'testStim',testStim);
assignin(mw,'pllTestCfg',pllTestCfg);
end
