function cfg=handover_test_parameters()
%HANDOVER_TEST_PARAMETERS Independent phase source; not a physical motor.
cfg.Duration=0.35;cfg.ElectricalSpeed=200;cfg.InitialAngle=0;
cfg.StartupAngleOffset=0.4;cfg.Ready=1;cfg.StartupMode=4;cfg.StartupFault=0;
cfg.ObserverValidTime=0.02;cfg.ResidualNorm=0.1;cfg.Enable=1;cfg.Reset=0;
end
