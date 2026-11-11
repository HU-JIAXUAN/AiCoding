function p=sensorless_foc_parameters()
%SENSORLESS_FOC_PARAMETERS Baseline SPMSM observer-controlled MIL fixture.
module=fileparts(fileparts(mfilename('fullpath')));
project=fileparts(fileparts(fileparts(fileparts(module))));
addpath(fullfile(project,'docs','scripts'));initialize_motor_paths();
p.pmsmCfg=pmsm_parameters();p.pmsmCfg.Lq=p.pmsmCfg.Ld;p.pmsmCfg.Position0=0.1;
p.currentCfg=current_parameters(p.pmsmCfg);p.currentCfg.Ts=50e-6;
p.currentCfg.Kaw=1/p.currentCfg.Ts;
p.inverterCfg=inverter_parameters();p.inverterCfg.PwmTs=p.currentCfg.Ts;
p.timingCfg=timing_parameters();p.timingCfg.Ts=p.currentCfg.Ts;p.timingCfg.FeedbackTicks=0;
p.motionCfg=motion_parameters(p.pmsmCfg);p.motionCfg.SpeedLimit=120;p.deadtimeCfg=deadtime_parameters();
p.experimentCfg=struct('UseInverter',1,'UseTiming',1,'Step',5e-6, ...
    'LogTs',p.currentCfg.Ts,'Duration',2);
p.focCfg=struct('Direction',1,'SpeedReference',80,'SpeedInitial',0,'CommandTime',0.05, ...
    'LoadTorque',0.1,'LoadTime',0.9,'Enable',1,'Reset',0,'ObserverEnable',1, ...
    'CurrentMax',8,'Kt',1.5*p.pmsmCfg.PolePairs*p.pmsmCfg.Flux, ...
    'VoltageAlignmentEnable',1,'AlignmentVoltageGain',p.pmsmCfg.Rs,'FrameCorrectionTolerance',1e-10);
p.refCfg=struct('SpeedTs',p.motionCfg.Ts,'SpeedKp',p.motionCfg.Kp*p.focCfg.Kt, ...
    'SpeedKi',p.motionCfg.Ki*p.focCfg.Kt,'SpeedKaw',1/p.motionCfg.Ts);
p.startupCfg=startup_parameters();p.startupCfg.Ts=p.currentCfg.Ts;
p.startupCfg=refresh_startup_parameters(p.startupCfg);
p.handoverCfg=handover_parameters();p.handoverCfg.Ts=p.currentCfg.Ts;
p.handoverCfg.AllowFlying=0;p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
p.smoCfg=smo_parameters();p.smoCfg.Ts=p.currentCfg.Ts;
p.smoCfg.Rs=p.pmsmCfg.Rs;p.smoCfg.L=p.pmsmCfg.Ld;p.smoCfg.Flux=p.pmsmCfg.Flux;
p.smoCfg=refresh_smo_parameters(p.smoCfg);
p.pllCfg=angle_tracking_parameters();p.pllCfg.Ts=p.currentCfg.Ts;p.pllCfg.MinMagnitude=p.smoCfg.MinEmf;
end
