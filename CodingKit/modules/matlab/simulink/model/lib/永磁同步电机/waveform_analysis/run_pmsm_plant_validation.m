function summary = run_pmsm_plant_validation()
%RUN_PMSM_PLANT_VALIDATION Validate saved models in this module.
modelRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(fileparts(modelRoot),'docs','scripts'));
report=run_motor_validation('pmsm_plant');
summary=report.pmsm_plant;
end
