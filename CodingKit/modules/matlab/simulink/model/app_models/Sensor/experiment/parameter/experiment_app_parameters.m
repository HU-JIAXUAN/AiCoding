function p=experiment_app_parameters()
%EXPERIMENT_APP_PARAMETERS Local composition of all motor experiment settings.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
% Apply motor-instance overrides here before computing controller gains.
p.pmsmCfg=pmsm_parameters();p.currentCfg=current_parameters(p.pmsmCfg);
p.inverterCfg=inverter_parameters();p.timingCfg=timing_parameters();
p.motionCfg=motion_parameters(p.pmsmCfg);p.feedforwardCfg=feedforward_parameters();
p.deadtimeCfg=deadtime_parameters();p.experimentCfg=experiment_parameters();
% App-specific control, inverter, timing and scene overrides also belong here.
end
