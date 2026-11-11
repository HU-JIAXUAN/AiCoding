function cfg=refresh_sigmoid_smo_parameters(cfg)
%REFRESH_SIGMOID_SMO_PARAMETERS Recompute exact RL factors and slope bound.
names={'Ts','Rs','L','SlidingGain','Slope','MinEmf','MinOmega','MaxOmega','MaxResidual','MaxVoltage','MaxCurrent','MaxEstimate'};
for k=1:numel(names),validateattributes(cfg.(names{k}),{'numeric'},{'scalar','real','finite','positive'});end
cfg.A=exp(-cfg.Rs*cfg.Ts/cfg.L);cfg.B=-expm1(-cfg.Rs*cfg.Ts/cfg.L)/cfg.Rs;
cfg.MaximumInjectionSlope=cfg.SlidingGain*cfg.Slope/2;
cfg.LocalErrorPole=cfg.A-cfg.B*cfg.MaximumInjectionSlope;
assert(abs(cfg.LocalErrorPole)<1,'The maximum-slope discrete error pole must lie inside the unit circle.');
assert(cfg.MaxOmega>cfg.MinOmega);
cfg.Settings=[cfg.A;cfg.B;cfg.SlidingGain;cfg.Slope;cfg.MaxVoltage;cfg.MaxCurrent;cfg.MaxEstimate];
end
