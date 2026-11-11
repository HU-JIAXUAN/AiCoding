function cfg=refresh_kalman_parameters(cfg)
%REFRESH_KALMAN_PARAMETERS Shared EKF/UKF current-correction parameter packing.
m=cfg.Model;assert(m.Ts>0 && m.Rs>=0 && m.L>0 && m.Flux>0 && m.PolePairs>=1);
assert(numel(cfg.InitialStd)==4 && all(cfg.InitialStd>0));
assert(numel(cfg.ProcessNoiseDensity)==4 && all(cfg.ProcessNoiseDensity>0));
assert(numel(cfg.MeasurementStd)==2 && all(cfg.MeasurementStd>0));
assert(cfg.InitialOmega>=0 && cfg.InitialOmega<=cfg.MaxOmega);
assert(cfg.QualificationTime>0 && cfg.MinOmega>0 && cfg.MinEmf>0 && cfg.MaxNIS>0);
assert(cfg.MaxThetaStd>0 && cfg.MaxOmegaStd>0 && cfg.AngleRateTimeConstant>0 && cfg.MaxRateMismatch>0);
assert(cfg.MaxInputCurrent>0 && cfg.MaxInputVoltage>0 && cfg.MaxOmega>cfg.MinOmega);
cfg.InitialAngle=atan2(sin(cfg.InitialAngle),cos(cfg.InitialAngle));
cfg.InitialVariance=cfg.InitialStd(:).^2;
cfg.ProcessVariance=m.Ts*cfg.ProcessNoiseDensity(:);
cfg.MeasurementVariance=cfg.MeasurementStd(:).^2;
cfg.QualificationSamples=ceil(cfg.QualificationTime/m.Ts);
cfg.AngleRateAlpha=m.Ts/(m.Ts+cfg.AngleRateTimeConstant);
cfg.Settings=[m.Ts;m.Rs;m.L;m.Flux;cfg.InitialOmega;cfg.InitialAngle;cfg.InitialVariance; ...
    cfg.ProcessVariance;cfg.MeasurementVariance;cfg.QualificationSamples;cfg.MinOmega;cfg.MinEmf; ...
    cfg.MaxNIS;cfg.MaxThetaStd;cfg.MaxOmegaStd;cfg.AngleRateAlpha;cfg.MaxRateMismatch; ...
    cfg.MaxOmega;cfg.MaxInputCurrent;cfg.MaxInputVoltage];
assert(numel(cfg.Settings)==27 && all(isfinite(cfg.Settings)));
end
