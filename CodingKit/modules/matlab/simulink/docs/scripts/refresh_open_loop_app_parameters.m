function p=refresh_open_loop_app_parameters(p)
%REFRESH_OPEN_LOOP_APP_PARAMETERS Derived settings, periods and physical limits.
p.openLoopCfg=refresh_open_loop_drive_parameters(p.openLoopCfg);
assert(abs(p.currentCfg.Ts-p.openLoopCfg.Ts)<eps(p.currentCfg.Ts));
assert(abs(p.currentCfg.Ts/p.experimentCfg.Step-round(p.currentCfg.Ts/p.experimentCfg.Step))<1e-9);
assert(p.experimentCfg.Duration>0&&p.experimentCfg.Step>0&&p.experimentCfg.LogPeriod>=p.currentCfg.Ts);
assert(p.powerCfg.Vdc>0&&p.powerCfg.MinDuty>=0&&p.powerCfg.MinDuty<.5);
p.inverterCfg=struct('Vdc',1,'MinDuty',p.powerCfg.MinDuty,'PwmTs',p.currentCfg.Ts, ...
    'LinearLimit',(1-2*p.powerCfg.MinDuty)/sqrt(3));
p.openLoopCfg.VoltageFraction=p.inverterCfg.LinearLimit;
p.openLoopCfg=refresh_open_loop_drive_parameters(p.openLoopCfg);
names=fieldnames(p.motorCfg);
for k=1:numel(names),p.bridgeCfg.(names{k})=p.motorCfg.(names{k});end
p.bridgeCfg.Ts=p.experimentCfg.Step;p.bridgeCfg.Vdc=p.powerCfg.Vdc;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
end
