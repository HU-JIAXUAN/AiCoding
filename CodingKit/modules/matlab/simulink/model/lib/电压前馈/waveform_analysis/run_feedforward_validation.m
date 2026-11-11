function summary = run_feedforward_validation()
%RUN_FEEDFORWARD_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('feedforward');
summary=report.feedforward;
end
