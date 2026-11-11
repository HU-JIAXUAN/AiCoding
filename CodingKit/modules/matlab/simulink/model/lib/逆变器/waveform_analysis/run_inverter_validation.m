function summary = run_inverter_validation()
%RUN_INVERTER_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('inverter');
summary=report.inverter;
end
