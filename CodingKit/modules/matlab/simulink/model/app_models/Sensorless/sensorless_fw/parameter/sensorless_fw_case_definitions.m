function cases=sensorless_fw_case_definitions()
%SENSORLESS_FW_CASE_DEFINITIONS Explicit physical four-quadrant/FW fixtures.
p=sensorless_fw_parameters();
cases=entry('forward_high_speed',p,true,true,false,false);
q=p;q.focCfg.Direction=-1;q.focCfg.SpeedReference=-210;q.focCfg.LoadTorque=-0.1;
cases(end+1)=entry('reverse_high_speed',q,true,true,false,false);
q=p;q.experimentCfg.Duration=2.4;q.focCfg.LoadTime=1.4;q.focCfg.LoadTorque=-0.6;
cases(end+1)=entry('forward_regeneration',q,true,true,true,false);
q=p;q.experimentCfg.Duration=2.4;q.focCfg.Direction=-1;q.focCfg.SpeedReference=-210;
q.focCfg.LoadTime=1.4;q.focCfg.LoadTorque=0.6;
cases(end+1)=entry('reverse_regeneration',q,true,true,true,false);
q=p;q.experimentCfg.Duration=2.6;q.fwCfg.BusTimes=[0,1.4,2];q.fwCfg.BusValues=[48,46,48];
cases(end+1)=entry('bus_drop_recovery',q,true,true,false,false);
q=p;q.experimentCfg.Duration=2.6;q.focCfg.SpeedReference=260;
cases(end+1)=entry('unreachable_high_reference',q,false,true,false,false);
q=p;q.refCfg.FwEnable=0;
cases(end+1)=entry('weakening_disabled_counterexample',q,false,false,false,true);
end
function item=entry(name,p,tracking,weakening,regeneration,counterexample)
item=struct('name',name,'parameters',p,'expect_tracking',tracking, ...
    'require_weakening',weakening,'require_regeneration',regeneration, ...
    'expected_counterexample',counterexample);
end
