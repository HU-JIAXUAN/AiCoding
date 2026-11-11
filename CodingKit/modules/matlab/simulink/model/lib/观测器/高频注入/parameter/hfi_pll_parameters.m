function cfg=hfi_pll_parameters(hfiCfg)
%HFI_PLL_PARAMETERS Common PLL configured for doubled electrical phase.
cfg=angle_tracking_parameters();
cfg.Ts=hfiCfg.Ts;cfg.NaturalFrequency=30;cfg.Damping=0.707;
frequency=2*pi*cfg.NaturalFrequency;
cfg.Kp=2*cfg.Damping*frequency;cfg.Ki=frequency^2;cfg.Kaw=2*frequency;
cfg.OmegaMax=2*hfiCfg.MaxOmega;cfg.MinMagnitude=hfiCfg.MinResponse;
cfg.LockError=0.12;cfg.LockSamples=round(0.005/hfiCfg.Ts);
cfg.Theta0=hfiCfg.InitialTrackerPhase;cfg.Omega0=0;
end
