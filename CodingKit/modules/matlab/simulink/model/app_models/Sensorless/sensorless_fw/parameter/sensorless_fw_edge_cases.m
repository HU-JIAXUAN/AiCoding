function cases=sensorless_fw_edge_cases()
%SENSORLESS_FW_EDGE_CASES Measured-EMF startup and moving restart fixtures.
p=sensorless_fw_parameters();
q=p;q.experimentCfg.Duration=0.2;q.pmsmCfg.Speed0=80;
cases=make('moving_forward_refused',q,'moving_refused',0);
q=p;q.experimentCfg.Duration=0.2;q.pmsmCfg.Speed0=-80;q.focCfg.Direction=-1;q.focCfg.SpeedReference=-210;
cases(end+1)=make('moving_reverse_refused',q,'moving_refused',0);
q=p;q.experimentCfg.Duration=0.2;q.focCfg.ObserverEnable=0;
cases(end+1)=make('observer_disabled_start',q,'observer_disabled',0);
q=p;q.experimentCfg.Duration=2.1;
item=make('rotating_reset_release',q,'moving_exit',1.55);
item.stimulus.signals.values(item.stimulus.time>=1.55-q.currentCfg.Ts/4 & item.stimulus.time<1.56-q.currentCfg.Ts/4,4)=1;
cases(end+1)=item;
item=make('rotating_disable_reenable',q,'moving_exit',1.55);
item.stimulus.signals.values(item.stimulus.time>=1.55-q.currentCfg.Ts/4 & item.stimulus.time<1.60-q.currentCfg.Ts/4,3)=0;
cases(end+1)=item;
item=make('rotating_direction_change',q,'moving_exit',1.55);
after=item.stimulus.time>=1.55-q.currentCfg.Ts/4;
item.stimulus.signals.values(after,5)=-1;item.stimulus.signals.values(after,1)=-210;
cases(end+1)=item;
q=p;q.experimentCfg.Duration=4.2;q.pmsmCfg.B=0.003;
q.focCfg.SpeedReference=80;q.focCfg.LoadTorque=0;
item=make('direction_stop_then_restart',q,'restart',1.5);
after=item.stimulus.time>=1.5-q.currentCfg.Ts/4;
item.stimulus.signals.values(after,5)=-1;item.stimulus.signals.values(after,1)=-80;
cases(end+1)=item;
q=p;q.experimentCfg.Duration=2.1;
item=make('observer_loss_exit',q,'observer_loss',1.55);
item.stimulus.signals.values(item.stimulus.time>=1.55-q.currentCfg.Ts/4,6)=0;
cases(end+1)=item;
q=p;q.experimentCfg.Duration=0.2;q.pmsmCfg.Speed0=80;q.startGuardCfg.Enable=0;
cases(end+1)=make('moving_alignment_bypass_counterexample',q,'counterexample',0);
end
function item=make(name,p,kind,event)
p=refresh_sensorless_fw_parameters(p);
item=struct('name',name,'parameters',p,'stimulus',sensorless_fw_stimulus(p),'kind',kind,'event_time',event);
end
