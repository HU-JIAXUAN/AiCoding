function initialize_emf_test(model)
%INITIALIZE_EMF_TEST Load module-owned defaults into the model workspace.
module=fileparts(fileparts(mfilename('fullpath')));pll=fullfile(fileparts(fileparts(module)),'相位跟踪');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(pll,'src'),fullfile(pll,'parameter'));
if strcmp(model,'LinearEmfTest'),kind='spmsm';else,kind='ipmsm';end
emfCfg=emf_parameters(kind);emfTestCfg=emf_test_parameters();pllCfg=angle_tracking_parameters();
pllCfg.Ts=emfCfg.Ts;pllCfg.MinMagnitude=emfCfg.MinEmf;
time=(0:round(emfTestCfg.Duration/emfCfg.Ts))'*emfCfg.Ts;one=ones(size(time));
[testStim,~]=emf_fixture(time,emfTestCfg.ElectricalSpeed*one,emfTestCfg.InitialAngle, ...
    emfTestCfg.Id*one,emfTestCfg.Iq*one,emfCfg);
testStim.signals.values(:,6)=emfTestCfg.Enable;testStim.signals.values(:,7)=emfTestCfg.Reset;
if ~isempty(emfTestCfg.Direction),testStim.signals.values(:,5)=emfTestCfg.Direction;end
workspace=get_param(model,'ModelWorkspace');
assignin(workspace,'emfCfg',emfCfg);assignin(workspace,'pllCfg',pllCfg);
assignin(workspace,'emfTestCfg',emfTestCfg);assignin(workspace,'testStim',testStim);
end
