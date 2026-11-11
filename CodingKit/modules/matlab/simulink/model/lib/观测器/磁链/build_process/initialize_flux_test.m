function initialize_flux_test(model)
%INITIALIZE_FLUX_TEST Load local configuration and an independent trajectory.
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'), ...
    fullfile(lib,'相位跟踪','src'),fullfile(lib,'相位跟踪','parameter'), ...
    fullfile(lib,'观测器','反电势','build_process'));
fluxCfg=flux_parameters();fluxTestCfg=flux_test_parameters();pllCfg=angle_tracking_parameters();
pllCfg.Ts=fluxCfg.Ts;pllCfg.MinMagnitude=fluxCfg.MinFlux;
time=(0:round(fluxTestCfg.Duration/fluxCfg.Ts))'*fluxCfg.Ts;one=ones(size(time));
motor=struct('Ts',fluxCfg.Ts,'Rs',fluxCfg.Rs,'Ld',fluxCfg.L,'Lq',fluxCfg.L, ...
    'Flux',fluxCfg.Flux,'MinOmega',fluxCfg.MinOmega);
[testStim,~]=emf_fixture(time,fluxTestCfg.ElectricalSpeed*one,fluxTestCfg.InitialAngle, ...
    fluxTestCfg.Id*one,fluxTestCfg.Iq*one,motor);
testStim.signals.values(:,6)=fluxTestCfg.Enable;testStim.signals.values(:,7)=fluxTestCfg.Reset;
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'fluxCfg',fluxCfg);assignin(workspace,'pllCfg',pllCfg);
assignin(workspace,'fluxTestCfg',fluxTestCfg);assignin(workspace,'testStim',testStim);
end
