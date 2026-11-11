function cfg=mras_parameters()
%MRAS_PARAMETERS SPMSM current-model MRAS configuration, all SI units.
cfg.Ts=50e-6;cfg.Rs=.5;cfg.L=1e-3;cfg.Flux=.035;cfg.PolePairs=4;
cfg.BandwidthHz=30;cfg.Damping=.7;cfg.Kaw=20;
cfg.ResidualCutoffHz=500;cfg.InitialAngle=0;cfg.InitialOmega=300;
cfg.MinBootstrapOmega=20;cfg.MaxOmega=2000;cfg.MinOmega=30;cfg.MinEmf=1;
cfg.MaxNormalizedD=.12;cfg.MaxNormalizedQ=.3;cfg.QualificationTime=.02;
cfg=refresh_mras_parameters(cfg);
end
