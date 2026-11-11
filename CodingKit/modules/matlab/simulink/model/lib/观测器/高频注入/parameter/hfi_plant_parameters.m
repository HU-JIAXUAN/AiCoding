function cfg=hfi_plant_parameters(testCfg)
%HFI_PLANT_PARAMETERS Compose the physical motor fixture without angle feedback.
cfg=pmsm_hf_parameters();
cfg.Position0=testCfg.InitialElectricalAngle/cfg.PolePairs;
cfg.SaturationDepth=testCfg.SaturationDepth;
cfg.CrossInductance=testCfg.CrossInductance;
cfg.MechanicalEnabled=testCfg.MechanicalEnabled;
cfg=refresh_pmsm_hf_parameters(cfg);
end
