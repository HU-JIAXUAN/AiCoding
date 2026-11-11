function cfg=sigmoid_smo_parameters()
%SIGMOID_SMO_PARAMETERS Book12.3.3 smooth SPMSM injection without explicit LPF.
cfg.Ts=50e-6;cfg.Rs=.5;cfg.L=1e-3;cfg.Flux=.035;cfg.PolePairs=4;
cfg.SlidingGain=60;          % V, bounded injection per axis
cfg.Slope=.6;               % 1/A, sigmoid exponent slope, not small-signal gain
cfg.MinEmf=1;cfg.MinOmega=30;cfg.MaxOmega=800;cfg.MaxResidual=2;
cfg.MaxVoltage=200;cfg.MaxCurrent=20;cfg.MaxEstimate=40;
cfg=refresh_sigmoid_smo_parameters(cfg);
end
