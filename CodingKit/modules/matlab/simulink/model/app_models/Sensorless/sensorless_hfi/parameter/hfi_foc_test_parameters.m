function cfg=hfi_foc_test_parameters()
%HFI_FOC_TEST_PARAMETERS Physical low-speed FOC and fault-injection fixture.
cfg=hfi_startup_test_parameters();
cfg.Duration=1.2;cfg.SpeedInitial=0;cfg.SpeedReference=8;cfg.CommandTime=.14;
cfg.TorqueReference=.02;cfg.Mode=1;
cfg.LoadTorque=.02;cfg.LoadTime=.7;
end
