function cfg=hfi_probe_parameters()
%HFI_PROBE_PARAMETERS Orthogonal physical excitation and tensor qualification.
cfg.Ts=50e-6;cfg.InjectionVoltage=5;cfg.WarmupSamples=32;cfg.CaptureSamples=256;
cfg.MinSaliencyRatio=0.08;cfg.MaxSaliencyRatio=0.8;
cfg.MinInverseInductance=100;cfg.MaxInverseInductance=5000;
cfg.MaxFitResidual=0.2;cfg.MaxAsymmetry=0.1;
cfg.MinVoltageRms=1;cfg.MaxCurrent=2;
cfg.ProbeAxis=0;cfg.CrossPhase=0;
cfg=refresh_hfi_probe_parameters(cfg);
end
