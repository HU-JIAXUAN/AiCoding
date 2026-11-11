function cfg=flux_parameters()
%FLUX_PARAMETERS SPMSM voltage-model flux observer in SI peak units.
cfg.Ts=50e-6;cfg.Rs=0.5;cfg.L=1e-3;cfg.Flux=0.035;cfg.PolePairs=4;
cfg.LeakEnable=1;cfg.LeakHz=10;cfg.DcEnable=1;cfg.DcHz=3;
cfg.FrequencyHz=5;       % filtered estimated speed used for compensation
cfg.MinCompOmega=20;cfg.FullCompOmega=100;cfg.MaxCompGain=4;
cfg.MinFlux=0.015;cfg.MaxFlux=1.5*cfg.Flux;
cfg.MinOmega=120;cfg.MaxResidual=5; % A-equivalent flux magnitude residual
cfg=refresh_flux_parameters(cfg);
end
