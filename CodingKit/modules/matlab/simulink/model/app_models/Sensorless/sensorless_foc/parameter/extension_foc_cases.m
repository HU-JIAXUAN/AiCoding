function cases=extension_foc_cases(kind)
%EXTENSION_FOC_CASES Shared actual-plant takeovers and controlled exits.
p=extension_foc_parameters(kind);cases=entry('forward',p,'tracking');
q=p;q.focCfg.Direction=-1;q.focCfg.SpeedReference=-80;q.focCfg.LoadTorque=-.1;
cases(end+1)=entry('reverse',q,'tracking');
q=p;q.pmsmCfg.Position0=2.6/q.pmsmCfg.PolePairs;
cases(end+1)=entry('initial_angle',q,'tracking');
q=p;q.inverterCfg.Vdc=36;q.fwCfg.BusValues=36;
cases(end+1)=entry('lower_bus',q,'tracking');
q=p;
if ismember(char(kind),{'mras','sigmoid'}),q.observerCfg.Rs=1.15*q.observerCfg.Rs;
else,q.observerCfg.Model.Rs=1.15*q.observerCfg.Model.Rs;end
cases(end+1)=entry('observer_resistance_mismatch',q,'tracking');
q=p;q.experimentCfg.Duration=1.8;
cases(end+1)=entry('observer_loss',q,'observer_loss');
cases(end+1)=entry('rotating_reset',q,'moving_exit');
q=p;q.experimentCfg.Duration=.2;q.pmsmCfg.Speed0=80;
cases(end+1)=entry('moving_forward_refused',q,'moving_refused');
q.focCfg.Direction=-1;q.focCfg.SpeedReference=-80;q.pmsmCfg.Speed0=-80;
cases(end+1)=entry('moving_reverse_refused',q,'moving_refused');
q=p;q.experimentCfg.Duration=.2;q.focCfg.ObserverEnable=0;
cases(end+1)=entry('observer_disabled_start',q,'observer_disabled');
end
function item=entry(name,p,classification)
item=struct('name',name,'parameters',p,'kind',classification,'event_time',1.55);
end
