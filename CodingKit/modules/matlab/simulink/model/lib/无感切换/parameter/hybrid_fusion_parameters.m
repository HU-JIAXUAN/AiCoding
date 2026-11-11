function cfg=hybrid_fusion_parameters()
%HYBRID_FUSION_PARAMETERS Two-tracker electrical-angle fusion and HFI scheduling.
cfg.Ts=50e-6;
cfg.LowOmega=40;cfg.HighOmega=60;          % signed-speed magnitude thresholds, rad/s
cfg.LowMaxOmega=80;cfg.HighMinOmega=30;  % each observer's admissible speed range
cfg.MaxPhaseGap=.7;cfg.MaxSpeedGap=30;   % rad, electrical rad/s
cfg.QualificationTime=.01;cfg.LossTime=.002;
cfg.BlendTime=.05;cfg.InjectionRampTime=.02;
cfg.InjectionResumeOmega=65;cfg.InjectionOffOmega=75;
cfg.PhaseCorrectionRate=20;             % electrical rad/s beyond base rotation
cfg.MaxPhaseInnovation=.2;              % rad against that observer's own prediction
cfg.MinInjectionScale=.1;
cfg.AllowHighStart=1;
cfg=refresh_hybrid_fusion_parameters(cfg);
end
