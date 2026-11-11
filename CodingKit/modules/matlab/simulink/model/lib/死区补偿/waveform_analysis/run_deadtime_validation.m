function summary = run_deadtime_validation()
%RUN_DEADTIME_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('deadtime');
summary=report.deadtime;
end
