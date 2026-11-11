function cfg=hybrid_fusion_test_parameters()
%HYBRID_FUSION_TEST_PARAMETERS Analytic two-tracker fixture, not a motor plant.
cfg.Duration=1.3;cfg.InitialAngle=.3;
cfg.InitialOmega=20;cfg.PeakOmega=100;
cfg.RampStart=.1;cfg.RampEnd=.5;cfg.DownStart=.7;cfg.DownEnd=1.1;
cfg.LowPhaseBias=-.03;cfg.HighPhaseBias=.02;
cfg.ReturnPi=1;cfg.ReturnTime=.85;
cfg.Enable=1;cfg.Reset=0;
end
