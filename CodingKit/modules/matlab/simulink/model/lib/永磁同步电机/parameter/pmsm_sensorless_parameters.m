function cfg=pmsm_sensorless_parameters()
%PMSM_SENSORLESS_PARAMETERS Shared four-state SPMSM estimation-model parameters.
% L is the single SPMSM inductance. Existing IPMSM Lq defaults are unchanged.
motor=pmsm_parameters();
cfg.Ts=50e-6;cfg.Rs=motor.Rs;cfg.L=motor.Ld;cfg.Flux=motor.Flux;cfg.PolePairs=motor.PolePairs;
end
