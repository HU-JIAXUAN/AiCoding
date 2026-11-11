function cfg=refresh_flux_parameters(cfg)
%REFRESH_FLUX_PARAMETERS Validate editable values and refresh discrete factors.
assert(cfg.Ts>0 && cfg.Rs>=0 && cfg.L>0 && cfg.Flux>0 && cfg.PolePairs>=1);
assert(ismember(cfg.LeakEnable,[0,1]) && ismember(cfg.DcEnable,[0,1]));
assert(cfg.FrequencyHz>0 && cfg.MinCompOmega>0 && cfg.FullCompOmega>cfg.MinCompOmega);
assert(cfg.MaxCompGain>=1 && cfg.MinOmega>0 && cfg.MinFlux>0 && cfg.MaxFlux>cfg.MinFlux && cfg.MaxResidual>0);
if cfg.LeakEnable
    assert(cfg.LeakHz>0);rate=2*pi*cfg.LeakHz;
    cfg.LeakA=exp(-rate*cfg.Ts);cfg.LeakB=-expm1(-rate*cfg.Ts)/rate;
else
    cfg.LeakA=1;cfg.LeakB=cfg.Ts;
end
if cfg.DcEnable
    assert(cfg.DcHz>0);cfg.DcA=exp(-2*pi*cfg.DcHz*cfg.Ts);
else
    cfg.DcA=1;
end
cfg.FrequencyA=exp(-2*pi*cfg.FrequencyHz*cfg.Ts);
end
