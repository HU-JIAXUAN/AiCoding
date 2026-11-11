function p=refresh_sensorless_fw_parameters(p)
%REFRESH_SENSORLESS_FW_PARAMETERS Repack derived values without retuning loops.
assert(p.pmsmCfg.Lq>p.pmsmCfg.Ld && p.pmsmCfg.Ld>0);
assert(ismember(p.startGuardCfg.Enable,[0,1]));
assert(isfinite(p.startGuardCfg.ObserveTime)&&p.startGuardCfg.ObserveTime>=p.currentCfg.Ts);
assert(isfinite(p.startGuardCfg.MaxStartEmf)&&p.startGuardCfg.MaxStartEmf>0);
p.startGuardCfg.ObserveTicks=ceil(p.startGuardCfg.ObserveTime/p.currentCfg.Ts);
assert(ismember(p.focCfg.Direction,[-1,1]));
assert(p.inverterCfg.Vdc>0 && p.currentCfg.Ts>0 && p.experimentCfg.Step>0);
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9);
assert(abs(p.refCfg.FwTs/p.currentCfg.Ts-round(p.refCfg.FwTs/p.currentCfg.Ts))<1e-9);
assert(all(abs([p.emfCfg.Ts,p.pllCfg.Ts,p.startupCfg.Ts,p.handoverCfg.Ts,p.timingCfg.Ts]-p.currentCfg.Ts)<eps(p.currentCfg.Ts)));
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
% Existing circle limiter/SVPWM use a local one-volt configuration. The App
% explicitly divides by runtime Vdc before them, then restores volts afterward.
p.normalizedInverterCfg=p.inverterCfg;
p.normalizedInverterCfg.Vdc=1;
p.normalizedInverterCfg.LinearLimit=(1-2*p.inverterCfg.MinDuty)/sqrt(3);
p.refCfg=refresh_mtpa_tables(p.refCfg,p.pmsmCfg);
p.startupCfg=refresh_startup_parameters(p.startupCfg);
p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
fields=fieldnames(p.pmsmCfg);
for k=1:numel(fields)
    assert(isfield(p.bridgeCfg,fields{k}));p.bridgeCfg.(fields{k})=p.pmsmCfg.(fields{k});
end
p.bridgeCfg.Ts=p.experimentCfg.Step;p.bridgeCfg.Vdc=p.inverterCfg.Vdc;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
assert(numel(p.fwCfg.BusTimes)==numel(p.fwCfg.BusValues));
assert(p.fwCfg.BusTimes(1)==0 && all(diff(p.fwCfg.BusTimes)>0));
assert(all(isfinite(p.fwCfg.BusValues)) && all(p.fwCfg.BusValues>0));
assert(all(p.fwCfg.BusTimes>=0) && all(p.fwCfg.BusTimes<=p.experimentCfg.Duration));
assert(all(abs(p.fwCfg.BusTimes/p.currentCfg.Ts-round(p.fwCfg.BusTimes/p.currentCfg.Ts))<1e-8));
end
