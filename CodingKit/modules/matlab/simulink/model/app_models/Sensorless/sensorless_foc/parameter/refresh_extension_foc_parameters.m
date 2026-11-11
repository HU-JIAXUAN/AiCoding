function p=refresh_extension_foc_parameters(p)
%REFRESH_EXTENSION_FOC_PARAMETERS Repack fixture and observer state settings.
spec=extension_foc_spec(p.extensionCfg.Kind);m=p.pmsmCfg;
assert(m.Ld==m.Lq&&m.Ld>0,'These observer implementations require SPMSM.');
assert(ismember(p.focCfg.Direction,[-1,1]));
assert(p.currentCfg.Ts>0&&p.experimentCfg.Step>0&&p.experimentCfg.Duration>0);
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9);
assert(all(abs([p.timingCfg.Ts,p.startupCfg.Ts,p.handoverCfg.Ts]-p.currentCfg.Ts)<eps(p.currentCfg.Ts)));
assert(p.refCfg.MtpaEnable==0&&p.refCfg.FwEnable==0);
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.normalizedInverterCfg=p.inverterCfg;p.normalizedInverterCfg.Vdc=1;
p.normalizedInverterCfg.LinearLimit=(1-2*p.inverterCfg.MinDuty)/sqrt(3);
p.refCfg=refresh_mtpa_tables(p.refCfg,m);
p.startupCfg=refresh_startup_parameters(p.startupCfg);
p.handoverCfg=refresh_handover_parameters(p.handoverCfg);
assert(ismember(p.startGuardCfg.Enable,[0,1])&&p.startGuardCfg.ObserveTime>=p.currentCfg.Ts);
assert(isfinite(p.startGuardCfg.MaxStartVoltage)&&p.startGuardCfg.MaxStartVoltage>0);
p.startGuardCfg.ObserveTicks=ceil(p.startGuardCfg.ObserveTime/p.currentCfg.Ts);
names=fieldnames(m);for k=1:numel(names),p.bridgeCfg.(names{k})=m.(names{k});end
p.bridgeCfg.Ts=p.experimentCfg.Step;p.bridgeCfg.Vdc=p.inverterCfg.Vdc;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
assert(numel(p.fwCfg.BusTimes)==numel(p.fwCfg.BusValues)&&p.fwCfg.BusTimes(1)==0);
assert(all(diff(p.fwCfg.BusTimes)>0)&&all(p.fwCfg.BusTimes>=0)&&all(p.fwCfg.BusTimes<=p.experimentCfg.Duration));
assert(all(isfinite(p.fwCfg.BusValues))&&all(p.fwCfg.BusValues>0));
assert(all(abs(p.fwCfg.BusTimes/p.currentCfg.Ts-round(p.fwCfg.BusTimes/p.currentCfg.Ts))<1e-8));
switch spec.kind
    case {'mras','sigmoid'}
        assert(p.observerCfg.Ts==p.currentCfg.Ts);
        if strcmp(spec.kind,'mras'),p.observerCfg=refresh_mras_parameters(p.observerCfg);
        else
            p.observerCfg=refresh_sigmoid_smo_parameters(p.observerCfg);
            assert(p.pllCfg.Ts==p.currentCfg.Ts&&p.pllCfg.MinMagnitude==p.observerCfg.MinEmf);
        end
    case {'ekf','ukf'}
        assert(p.observerCfg.Model.Ts==p.currentCfg.Ts);
        if strcmp(spec.kind,'ekf'),p.observerCfg=refresh_kalman_parameters(p.observerCfg);
        else,p.observerCfg=refresh_ukf_parameters(p.observerCfg);end
end
end
