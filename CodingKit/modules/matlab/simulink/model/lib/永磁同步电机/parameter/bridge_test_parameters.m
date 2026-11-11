function p=bridge_test_parameters()
%BRIDGE_TEST_PARAMETERS Reproducible coast -> short -> release MIL instance.
p.bridgeCfg=pmsm_bridge_parameters();
p.bridgeCfg.Speed0=80;p.bridgeCfg.Position0=0.1;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
p.bridgeTestCfg=struct('Duration',0.06,'ModeTimes',[0,0.015,0.025], ...
    'ModeValues',[0,2,0],'Duty',[0.5,0.5,0.5],'LoadTorque',0);
end
