function initialize_vf_app(model)
%INITIALIZE_VF_APP Reload the module's M configuration into Model Workspace.
module=fileparts(fileparts(mfilename('fullpath')));root=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(root,'docs','scripts'),fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'));
p=vf_app_parameters();workspace=get_param(model,'ModelWorkspace');clear(workspace);
names=fieldnames(p);for k=1:numel(names),assignin(workspace,names{k},p.(names{k}));end
testStim=open_loop_app_stimulus(p);testStim.time=[];
assignin(workspace,'testStim',testStim);
end
