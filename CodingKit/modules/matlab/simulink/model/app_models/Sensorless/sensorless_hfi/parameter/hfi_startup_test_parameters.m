function cfg=hfi_startup_test_parameters()
%HFI_STARTUP_TEST_PARAMETERS Physical startup, sensing and fault-injection setup.
cfg.Ts=50e-6;cfg.PlantStep=cfg.Ts/20;cfg.Duration=.3;
cfg.InitialElectricalAngle=.7;cfg.InitialElectricalSpeed=0;
cfg.SaturationDepth=.25;cfg.CrossInductance=0;cfg.MechanicalEnabled=1;
cfg.Enable=1;cfg.Reset=0;cfg.LoadTorque=0;
cfg.MeasurementNoise=0;cfg.NoiseSeed=42;cfg.CurrentOffset=zeros(3,1);
cfg.CurrentResolution=0;cfg.CurrentRange=8;
cfg.ActuationGain=1;cfg.ExecutionDelay=0;cfg.CurrentDelay=0;cfg.VoltageAlignmentDelay=0;
cfg.PulseNegativeGain=1;cfg.PulseFaultOffsetA=0;cfg.QualificationGate=1;
end
