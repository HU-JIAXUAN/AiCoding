function initialize_observer_compare(model)
%INITIALIZE_OBSERVER_COMPARE Install all defaults in the model workspace.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'));
p=observer_compare_parameters();workspace=get_param(model,'ModelWorkspace');
names=fieldnames(p);
for index=1:numel(names),assignin(workspace,names{index},p.(names{index}));end
end
