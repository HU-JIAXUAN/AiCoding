function cfg=hfi_parameters()
%HFI_PARAMETERS Pulsating square-wave axis observer using actual voltage/current.
cfg.Ts=50e-6;cfg.InjectionVoltage=5;
cfg.Ld=1e-3;cfg.Lq=1.5e-3;cfg.CrossInductance=0;
cfg.InitialAxis=0;cfg.MaxOmega=80;
cfg.MinVoltageStep=1;cfg.MaxCrossFraction=0.2;
cfg.MinResponse=0.01;cfg.MaxResponse=0.15;cfg.MinInjectionScale=0.1;
cfg.DemodBandwidth=300;cfg.DemodFilterEnabled=1;
cfg.UseMeasuredInverseAverage=0;
cfg=refresh_hfi_parameters(cfg);
end
