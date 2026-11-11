function cfg=handover_parameters()
%HANDOVER_PARAMETERS Capture, angle blending and loss-of-lock fixture limits.
cfg.Ts=50e-6;
cfg.MinOmega=100;              % electrical rad/s, validity after acquisition
cfg.MaxSpeedGap=80;            % electrical rad/s, software vs observed speed
cfg.MaxPhaseGap=0.9;           % electrical rad, ordinary I-f capture only
cfg.MaxResidual=1.5;           % A, observer current residual norm
cfg.CaptureTime=0.01;          % s, consecutive qualification before blending
cfg.BlendTime=0.1;             % s of qualified samples, beta=0 -> 1
cfg.LossTime=0.001;            % s, consecutive unhealthy samples before fault
cfg.MaxPhaseInnovation=0.15;  % rad, observed phase vs one-step prediction
cfg.AllowFlying=1;            % enable large phase-gap capture at ZERO current
cfg=refresh_handover_parameters(cfg);
end
