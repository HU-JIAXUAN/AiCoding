function initialize_smo_test(model)
%INITIALIZE_SMO_TEST Install SI SPMSM defaults and an independent analytic fixture.
module=fileparts(fileparts(mfilename('fullpath')));pllModule=fullfile(fileparts(fileparts(module)),'相位跟踪');
addpath(fullfile(module,'parameter'),fullfile(module,'src'), ...
    fullfile(pllModule,'parameter'),fullfile(pllModule,'src'));
smoCfg=smo_parameters();pllCfg=angle_tracking_parameters();pllCfg.MinMagnitude=smoCfg.MinEmf;
smoTestCfg=smo_test_parameters();t=(0:round(smoTestCfg.Duration/smoCfg.Ts))'*smoCfg.Ts;
[testStim,~]=smo_fixture(t,smoTestCfg.ElectricalSpeed*ones(size(t)),smoTestCfg.InitialAngle,smoTestCfg.Iq,smoCfg);
if ~isempty(smoTestCfg.Direction),testStim.signals.values(:,5)=smoTestCfg.Direction;end
testStim.signals.values(:,6)=smoTestCfg.Enable;testStim.signals.values(:,7)=smoTestCfg.Reset;
mw=get_param(model,'ModelWorkspace');assignin(mw,'smoCfg',smoCfg);
assignin(mw,'pllCfg',pllCfg);assignin(mw,'testStim',testStim);
assignin(mw,'smoTestCfg',smoTestCfg);
end
