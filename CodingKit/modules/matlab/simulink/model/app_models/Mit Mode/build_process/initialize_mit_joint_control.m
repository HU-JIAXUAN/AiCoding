function initialize_mit_joint_control(model)
%INITIALIZE_MIT_JOINT_CONTROL Resolve the shared libraries and reload defaults.
module = fileparts(fileparts(mfilename('fullpath')));
project = fileparts(fileparts(fileparts(module)));
addpath(fullfile(project,'docs','scripts'),fullfile(module,'parameter'));
initialize_motor_paths();
p = mit_joint_parameters();
workspace = get_param(model,'ModelWorkspace');
names = fieldnames(p);
for k = 1:numel(names)
    assignin(workspace,names{k},p.(names{k}));
end
end
