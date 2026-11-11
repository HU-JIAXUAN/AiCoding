function cfg=open_loop_drive_test_parameters()
%OPEN_LOOP_DRIVE_TEST_PARAMETERS Independent reference/interlock test fixture.
cfg.Duration=.8;cfg.Frequency=20;cfg.BusVoltage=48;cfg.Current=0;cfg.TerminalVoltage=0;
cfg.ValidationTs=1e-4;cfg.ObserveTime=.01;cfg.ObserveTimeout=.08;cfg.AlignTime=.08;cfg.AlignRampTime=.04;
cfg.FaultTime=.4;cfg.ClearEndTime=.41;cfg.LimitFrequency=120;cfg.LimitSlew=200;
cfg.LimitedBus=6;cfg.MovingTerminal=4;cfg.VfSlope=1;cfg.AlignVoltage=.5;cfg.PhaseTolerance=1e-10;
end
