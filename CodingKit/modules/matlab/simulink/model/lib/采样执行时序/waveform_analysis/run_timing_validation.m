function summary = run_timing_validation()
%RUN_TIMING_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('timing');
summary=report.timing;
end
