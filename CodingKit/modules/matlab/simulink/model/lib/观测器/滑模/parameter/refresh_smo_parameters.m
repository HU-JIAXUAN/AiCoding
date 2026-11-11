function cfg = refresh_smo_parameters(cfg)
%REFRESH_SMO_PARAMETERS Recompute coefficients after changing physical settings.
validateattributes(cfg.Ts,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.Rs,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.L,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.Boundary,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.SlidingGain,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(cfg.FilterHz,{'numeric'},{'scalar','real','finite','positive'});
assert(cfg.FilterHz < 0.5/cfg.Ts,'FilterHz must be below Nyquist.');
cfg.A = exp(-cfg.Rs*cfg.Ts/cfg.L);
cfg.B = -expm1(-cfg.Rs*cfg.Ts/cfg.L)/cfg.Rs;
cfg.FilterA = exp(-2*pi*cfg.FilterHz*cfg.Ts);
cfg.BoundaryPole = cfg.A-cfg.B*cfg.SlidingGain/cfg.Boundary;
assert(abs(cfg.BoundaryPole)<1, ...
    'The linearized boundary-layer current-error pole is outside the unit circle.');
assert(ismember(cfg.Compensate,[0,1]));
end
