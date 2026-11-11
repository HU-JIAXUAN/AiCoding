function summary = run_current_loop_validation()
%RUN_CURRENT_LOOP_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('current_loop');
summary=report.current_loop;
end
