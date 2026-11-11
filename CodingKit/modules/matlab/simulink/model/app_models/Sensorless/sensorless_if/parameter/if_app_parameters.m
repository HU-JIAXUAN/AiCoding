function p=if_app_parameters()
%IF_APP_PARAMETERS Local SI-unit defaults for the standalone IF App.
module=fileparts(fileparts(mfilename('fullpath')));root=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(root,'docs','scripts'));initialize_motor_paths();
p.motorCfg=pmsm_parameters();p.motorCfg.Lq=p.motorCfg.Ld;
p.motorCfg.B=1e-3;p.motorCfg.Position0=0;
p.openLoopCfg=open_loop_drive_parameters(1);
p.openLoopCfg.VfSlope=2*pi*p.motorCfg.Flux;
p.currentCfg=current_parameters(p.motorCfg);p.currentCfg.Ts=p.openLoopCfg.Ts;p.currentCfg.Kaw=1/p.currentCfg.Ts;
p.powerCfg=struct('Vdc',48,'MinDuty',.02);
p.experimentCfg=struct('Duration',2,'Step',p.currentCfg.Ts/5,'Frequency',40,'LoadTorque',.05,'LoadTime',1.5,'LogPeriod',.001);
p.bridgeCfg=pmsm_bridge_parameters();
p=refresh_open_loop_app_parameters(p);
end
