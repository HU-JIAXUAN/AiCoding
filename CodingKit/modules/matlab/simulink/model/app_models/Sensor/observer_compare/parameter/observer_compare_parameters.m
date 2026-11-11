function p=observer_compare_parameters()
%OBSERVER_COMPARE_PARAMETERS SPMSM mechanical-loop and observer comparison fixture.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
p.pmsmCfg=pmsm_parameters();p.pmsmCfg.Lq=p.pmsmCfg.Ld;
p.pmsmCfg.Position0=0.1;
p.currentCfg=current_parameters(p.pmsmCfg);p.currentCfg.Ts=50e-6;
p.inverterCfg=inverter_parameters();p.inverterCfg.PwmTs=p.currentCfg.Ts;
p.timingCfg=timing_parameters();p.timingCfg.Ts=p.currentCfg.Ts;
p.motionCfg=motion_parameters(p.pmsmCfg);
p.feedforwardCfg=feedforward_parameters();p.deadtimeCfg=deadtime_parameters();
p.experimentCfg=experiment_parameters();p.experimentCfg.Mode=1;
p.experimentCfg.Duration=0.8;p.experimentCfg.LogTs=p.currentCfg.Ts;
p.compareCfg=struct('Direction',1,'ObserverEnable',1,'ObserverReset',0);
p.smoCfg=smo_parameters();p.smoCfg.Ts=p.currentCfg.Ts;
p.smoCfg.Rs=p.pmsmCfg.Rs;p.smoCfg.L=p.pmsmCfg.Ld;
p.smoCfg.Flux=p.pmsmCfg.Flux;p.smoCfg.PolePairs=p.pmsmCfg.PolePairs;
p.smoCfg=refresh_smo_parameters(p.smoCfg);
p.pllCfg=angle_tracking_parameters();p.pllCfg.Ts=p.currentCfg.Ts;
p.pllCfg.MinMagnitude=p.smoCfg.MinEmf;
end
