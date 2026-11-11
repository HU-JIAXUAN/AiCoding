function p=refresh_flying_foc_parameters(p)
%REFRESH_FLYING_FOC_PARAMETERS Refresh derived fields after single-run edits.
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
assert(p.bridgeCfg.Ld==p.bridgeCfg.Lq,'Flux flying capture requires Ld=Lq.');
assert(abs(p.currentCfg.Ts*p.currentCfg.Kaw-1)<1e-12,'PI precharge requires Kaw=1/Ts.');
ratio=p.currentCfg.Ts/p.bridgeCfg.Ts;
assert(abs(ratio-round(ratio))<1e-10 && ratio>=1,'Control/plant rates must be integral.');
p.inverterCfg.Vdc=p.bridgeCfg.Vdc;
p.inverterCfg.PwmTs=p.currentCfg.Ts;
p.inverterCfg.LinearLimit=p.inverterCfg.Vdc/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.fluxCfg.Ts=p.currentCfg.Ts;p.fluxCfg.Rs=p.bridgeCfg.Rs;
p.fluxCfg.L=p.bridgeCfg.Ld;p.fluxCfg.Flux=p.bridgeCfg.Flux;
p.fluxCfg.PolePairs=p.bridgeCfg.PolePairs;p.fluxCfg=refresh_flux_parameters(p.fluxCfg);
p.pllCfg.Ts=p.currentCfg.Ts;p.pllCfg.MinMagnitude=p.fluxCfg.MinFlux;
c=p.flyingCfg;c.Ts=p.currentCfg.Ts;c.PolePairs=p.bridgeCfg.PolePairs;
positive={'MinOmega','MaxResidual','CaptureTime','PrechargeTime','LossTime', ...
    'Timeout','CaptureCurrentMax','CaptureVoltageMax','CurrentTrip', ...
    'SpeedKp','SpeedKi','SpeedKaw','CurrentMax','CurrentReferenceSlew'};
for k=1:numel(positive)
    validateattributes(c.(positive{k}),{'double'},{'scalar','real','finite','positive'});
end
assert(c.CaptureVoltageMax<=p.inverterCfg.LinearLimit);
assert(c.CurrentTrip>c.CurrentMax && c.CaptureCurrentMax<c.CurrentMax);
assert(c.Timeout>c.CaptureTime+c.PrechargeTime);
c.Vector=[c.Ts;c.PolePairs;c.MinOmega;c.MaxResidual; ...
    ceil(c.CaptureTime/c.Ts);ceil(c.PrechargeTime/c.Ts); ...
    ceil(c.LossTime/c.Ts);ceil(c.Timeout/c.Ts); ...
    c.CaptureCurrentMax;c.CaptureVoltageMax;c.CurrentTrip; ...
    c.SpeedKp;c.SpeedKi;c.SpeedKaw;c.CurrentMax;c.CurrentReferenceSlew];
p.flyingCfg=c;
end
