function p=initialize_flying_foc(model,p)
%INITIALIZE_FLYING_FOC Load module M defaults into this App's model workspace.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fileparts(mfilename('fullpath')));
% Existing project initialization registers only canonical library folders.
if exist('initialize_motor_paths','file')~=2
    project=fileparts(fileparts(fileparts(fileparts(module))));
    addpath(fullfile(project,'docs','scripts'));
end
initialize_motor_paths();
if nargin<2,p=flying_foc_parameters();end
p=refresh_flying_foc_parameters(p);workspace=get_param(model,'ModelWorkspace');
names=fieldnames(p);
for k=1:numel(names),assignin(workspace,names{k},p.(names{k}));end
assignin(workspace,'flyingStim',flying_foc_stimulus(p));
end
