function cfg=refresh_pmsm_hf_parameters(cfg)
%REFRESH_PMSM_HF_PARAMETERS Check a globally positive differential inductance.
assert(cfg.Rs>=0 && cfg.Ld>0 && cfg.Lq>0 && cfg.Flux>0);
assert(cfg.PolePairs>=1 && cfg.PolePairs==fix(cfg.PolePairs) && cfg.J>0 && cfg.B>=0);
assert(cfg.SaturationDepth>=0 && cfg.SaturationDepth<1 && cfg.SaturationCurrent>0);
assert(ismember(cfg.MechanicalEnabled,[0,1]));
assert(cfg.Ld*(1-cfg.SaturationDepth)*cfg.Lq>cfg.CrossInductance^2, ...
    'The differential inductance must remain positive definite for all currents.');
assert(cfg.MechanicalEnabled || cfg.Speed0==0,'A locked rotor must start at zero speed.');
cfg.Settings=[cfg.Rs;cfg.Ld;cfg.Lq;cfg.Flux;cfg.PolePairs;cfg.J;cfg.B; ...
    cfg.SaturationDepth;cfg.SaturationCurrent;cfg.CrossInductance;cfg.MechanicalEnabled];
cfg.InitialState=[cfg.Id0;cfg.Iq0;cfg.Speed0;cfg.Position0];
end
