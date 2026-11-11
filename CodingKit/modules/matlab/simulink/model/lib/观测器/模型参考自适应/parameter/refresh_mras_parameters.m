function cfg=refresh_mras_parameters(cfg)
%REFRESH_MRAS_PARAMETERS Recompute gains, qualification count and mask vector.
assert(cfg.Ts>0 && cfg.Rs>=0 && cfg.L>0 && cfg.Flux>0 && cfg.PolePairs>=1);
assert(cfg.BandwidthHz>0 && cfg.Damping>0 && cfg.Kaw>=0 && cfg.ResidualCutoffHz>0);
assert(cfg.MinBootstrapOmega>0 && cfg.MinOmega>=cfg.MinBootstrapOmega && cfg.MaxOmega>cfg.MinOmega);
assert(cfg.InitialOmega>=cfg.MinBootstrapOmega && cfg.InitialOmega<=cfg.MaxOmega);
assert(cfg.MinEmf>0 && cfg.MaxNormalizedD>0 && cfg.MaxNormalizedQ>0 && cfg.QualificationTime>0);
wn=2*pi*cfg.BandwidthHz;cfg.Kp=2*cfg.Damping*wn;cfg.Ki=wn^2;
cfg.ResidualAlpha=cfg.Ts/(cfg.Ts+1/(2*pi*cfg.ResidualCutoffHz));
cfg.QualificationSamples=ceil(cfg.QualificationTime/cfg.Ts);
cfg.Settings=[cfg.Ts;cfg.Rs;cfg.L;cfg.Flux;cfg.Kp;cfg.Ki;cfg.Kaw;cfg.ResidualAlpha; ...
    cfg.InitialAngle;cfg.InitialOmega;cfg.MinBootstrapOmega;cfg.MaxOmega;cfg.MinOmega; ...
    cfg.MinEmf;cfg.MaxNormalizedD;cfg.MaxNormalizedQ;cfg.QualificationSamples];
assert(all(isfinite(cfg.Settings)));
end
