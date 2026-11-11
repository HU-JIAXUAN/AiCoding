function p=bridge_bus_test_parameters()
%BRIDGE_BUS_TEST_PARAMETERS PWM voltage-drop/recovery fixture, all SI.
p=bridge_test_parameters();
p.bridgeCfg.Speed0=0;
p.bridgeCfg=refresh_pmsm_bridge_parameters(p.bridgeCfg);
p.bridgeTestCfg.Duration=0.06;
p.bridgeTestCfg.ModeTimes=0;p.bridgeTestCfg.ModeValues=1;
p.bridgeTestCfg.Duty=[0.6,0.4,0.5];
p.bridgeTestCfg.BusTimes=[0,0.02,0.04];
p.bridgeTestCfg.BusValues=[48,24,48];
end
