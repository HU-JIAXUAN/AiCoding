function initialize_observer_foc(model,kind)
%INITIALIZE_OBSERVER_FOC Initialize a runnable observer substitution App.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'waveform_analysis'));
p=observer_foc_parameters(kind);workspace=get_param(model,'ModelWorkspace');
if hasVariable(workspace,'smoCfg'),evalin(workspace,'clear smoCfg');end
names=fieldnames(p);
for k=1:numel(names),assignin(workspace,names{k},p.(names{k}));end
assignin(workspace,'testStim',sensorless_foc_stimulus(p));
end
