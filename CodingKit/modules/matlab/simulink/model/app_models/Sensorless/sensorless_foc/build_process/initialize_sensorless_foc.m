function initialize_sensorless_foc(model)
%INITIALIZE_SENSORLESS_FOC Assign local parameters and a repeatable input table.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
p=sensorless_foc_parameters();workspace=get_param(model,'ModelWorkspace');names=fieldnames(p);
for index=1:numel(names),assignin(workspace,names{index},p.(names{index}));end
assignin(workspace,'testStim',sensorless_foc_stimulus(p));
end
