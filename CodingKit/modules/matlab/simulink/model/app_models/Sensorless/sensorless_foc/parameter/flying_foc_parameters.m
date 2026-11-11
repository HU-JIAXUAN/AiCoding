function p=flying_foc_parameters()
%FLYING_FOC_PARAMETERS Local SPMSM flying-capture physical MIL fixture.
% Requires existing shared library parameter functions on the MATLAB path.
p.bridgeCfg=pmsm_bridge_parameters();
p.bridgeCfg.Lq=p.bridgeCfg.Ld; % This flux observer requires an SPMSM.
p.bridgeCfg.Speed0=80;p.bridgeCfg.Position0=0.1;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
p.currentCfg=current_parameters(p.bridgeCfg);p.currentCfg.Ts=50e-6;
p.currentCfg.Kaw=1/p.currentCfg.Ts;
p.inverterCfg=inverter_parameters();p.inverterCfg.Vdc=p.bridgeCfg.Vdc;
p.inverterCfg.PwmTs=p.currentCfg.Ts;
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.fluxCfg=flux_parameters();p.fluxCfg.Ts=p.currentCfg.Ts;
p.fluxCfg.Rs=p.bridgeCfg.Rs;p.fluxCfg.L=p.bridgeCfg.Ld;
p.fluxCfg.Flux=p.bridgeCfg.Flux;p.fluxCfg.PolePairs=p.bridgeCfg.PolePairs;
p.fluxCfg=refresh_flux_parameters(p.fluxCfg);
p.pllCfg=angle_tracking_parameters();p.pllCfg.Ts=p.currentCfg.Ts;
p.pllCfg.MinMagnitude=p.fluxCfg.MinFlux;
p.flyingCfg=struct('Ts',p.currentCfg.Ts,'PolePairs',p.bridgeCfg.PolePairs, ...
    'MinOmega',140,'MaxResidual',p.fluxCfg.MaxResidual, ...
    'CaptureTime',0.025,'PrechargeTime',0.01,'LossTime',0.001,'Timeout',0.6, ...
    'CaptureCurrentMax',0.5,'CaptureVoltageMax',0.9*p.inverterCfg.LinearLimit, ...
    'CurrentTrip',12,'SpeedKp',0.08,'SpeedKi',0.8,'SpeedKaw',20, ...
    'CurrentMax',8,'CurrentReferenceSlew',100);
p.experimentCfg=struct('Duration',1,'SpeedReference',100,'LoadTorque',0, ...
    'LoadTime',0.5,'Enable',1,'ResetTime',inf,'ResetDuration',0.005, ...
    'DisableTime',inf,'ReenableTime',inf,'ObserverOffTime',inf, ...
    'ObserverOnTime',inf);
p=refresh_flying_foc_parameters(p);
end
