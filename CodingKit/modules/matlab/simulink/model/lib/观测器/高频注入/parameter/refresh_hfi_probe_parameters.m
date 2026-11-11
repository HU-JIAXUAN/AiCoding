function cfg=refresh_hfi_probe_parameters(cfg)
%REFRESH_HFI_PROBE_PARAMETERS Validate dimensions, excitation and quality limits.
assert(cfg.Ts>0 && cfg.InjectionVoltage>0);
assert(cfg.WarmupSamples>=4 && cfg.CaptureSamples>=16);
assert(mod(cfg.WarmupSamples,4)==0 && mod(cfg.CaptureSamples,4)==0);
assert(cfg.MinSaliencyRatio>0 && cfg.MaxSaliencyRatio>cfg.MinSaliencyRatio && cfg.MaxSaliencyRatio<1);
assert(cfg.MinInverseInductance>0 && cfg.MaxInverseInductance>cfg.MinInverseInductance);
assert(cfg.MaxFitResidual>0 && cfg.MaxFitResidual<1 && cfg.MaxAsymmetry>0 && cfg.MaxAsymmetry<1);
assert(cfg.MinVoltageRms>0 && cfg.MaxCurrent>0 && isfinite(cfg.ProbeAxis) && isfinite(cfg.CrossPhase));
cfg.Settings=[cfg.Ts;cfg.InjectionVoltage;cfg.WarmupSamples;cfg.CaptureSamples; ...
    cfg.MinSaliencyRatio;cfg.MaxSaliencyRatio;cfg.MinInverseInductance;cfg.MaxInverseInductance; ...
    cfg.MaxFitResidual;cfg.MaxAsymmetry;cfg.MinVoltageRms;cfg.MaxCurrent;cfg.ProbeAxis;cfg.CrossPhase];
cfg.InitialState=zeros(19,1);
end
