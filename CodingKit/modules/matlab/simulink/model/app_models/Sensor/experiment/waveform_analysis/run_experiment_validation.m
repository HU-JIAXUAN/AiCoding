function summary = run_experiment_validation()
%RUN_EXPERIMENT_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('experiment');
summary=report.experiment;
end
