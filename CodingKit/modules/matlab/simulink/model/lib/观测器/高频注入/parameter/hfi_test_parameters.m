function cfg=hfi_test_parameters()
%HFI_TEST_PARAMETERS Physical PMSM fixture for axis-observer integration.
cfg.Duration=0.25;cfg.Ts=50e-6;cfg.PlantStep=cfg.Ts/20;
cfg.InitialElectricalAngle=0.7;cfg.InjectionScale=1;
cfg.Enable=1;cfg.Reset=0;cfg.LoadTorque=0;
cfg.MeasurementNoise=0;cfg.NoiseSeed=42;cfg.CurrentOffset=zeros(3,1);
cfg.CurrentResolution=0;cfg.CurrentRange=8;
cfg.CurrentDelay=0;cfg.VoltageAlignmentDelay=0;cfg.ExecutionDelay=0;
cfg.ActuationGain=1;
cfg.SaturationDepth=0;cfg.CrossInductance=0;cfg.MechanicalEnabled=1;
cfg.ExternalInverseAverage=0;
end
