function p=mtpa_fw_app_parameters()
%MTPA_FW_APP_PARAMETERS App-owned defaults; edit this file for the motor scenario.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
p.pmsmCfg=pmsm_parameters();
p.currentCfg=current_parameters(p.pmsmCfg);
p.inverterCfg=inverter_parameters();p.timingCfg=timing_parameters();
p.motionCfg=motion_parameters(p.pmsmCfg);
p.feedforwardCfg=feedforward_parameters();p.deadtimeCfg=deadtime_parameters();
p.experimentCfg=experiment_parameters();
% Application scenario: speed is mechanical rad/s; torque is signed N*m.
p.experimentCfg.Mode=1;
p.experimentCfg.Duration=2;
p.experimentCfg.SpeedReference=218;
p.experimentCfg.SpeedInitial=0;
p.experimentCfg.CommandTime=0.05;
p.experimentCfg.LoadTorque=0.05;
p.experimentCfg.LoadTime=0;
p.motionCfg.SpeedLimit=260;
p.feedforwardCfg.Enable=1;
% Allocator and speed gains follow the above motor/control definitions.
p.refCfg=mtpa_fw_parameters(p.pmsmCfg,p.inverterCfg,p.motionCfg);
p.refTestCfg=reference_test_parameters();
end
