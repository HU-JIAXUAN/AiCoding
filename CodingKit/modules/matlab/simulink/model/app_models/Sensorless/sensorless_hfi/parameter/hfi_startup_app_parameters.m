function cfg=hfi_startup_app_parameters()
%HFI_STARTUP_APP_PARAMETERS Compose library defaults in this App's local entry.
cfg.Test=hfi_startup_test_parameters();
cfg.HFI=hfi_parameters();cfg.HFI.Ts=cfg.Test.Ts;cfg.HFI.UseMeasuredInverseAverage=1;cfg.HFI=refresh_hfi_parameters(cfg.HFI);
cfg.PLL=hfi_pll_parameters(cfg.HFI);
cfg.Probe=hfi_probe_parameters();cfg.Probe.Ts=cfg.Test.Ts;cfg.Probe.CrossPhase=cfg.HFI.CrossPhase;cfg.Probe=refresh_hfi_probe_parameters(cfg.Probe);
cfg.Polarity=hfi_polarity_parameters();cfg.Polarity.Ts=cfg.Test.Ts;cfg.Polarity=refresh_hfi_polarity_parameters(cfg.Polarity);
cfg.Motor=hfi_plant_parameters(cfg.Test);cfg.Motor.Speed0=cfg.Test.InitialElectricalSpeed/cfg.Motor.PolePairs;
cfg.Motor=refresh_pmsm_hf_parameters(cfg.Motor);
end
