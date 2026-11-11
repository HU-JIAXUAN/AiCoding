function initialize_motor_model(model)
%INITIALIZE_MOTOR_MODEL Load local module defaults and independent test input.
%   Called by PostLoadFcn. Does not require variables in the base workspace.
[parameters,testStim]=motor_case_parameters(model);
mw=get_param(model,'ModelWorkspace');
names=fieldnames(parameters);
for k=1:numel(names),assignin(mw,names{k},parameters.(names{k}));end
assignin(mw,'testStim',testStim);
end
