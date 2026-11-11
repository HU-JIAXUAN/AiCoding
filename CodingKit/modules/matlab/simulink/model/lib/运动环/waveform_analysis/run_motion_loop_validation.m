function summary = run_motion_loop_validation()
%RUN_MOTION_LOOP_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('motion_loop');
summary=report.motion_loop;
end
