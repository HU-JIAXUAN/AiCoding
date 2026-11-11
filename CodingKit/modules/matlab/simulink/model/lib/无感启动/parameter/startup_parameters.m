function cfg=startup_parameters()
%STARTUP_PARAMETERS Default SI-unit fixture for alignment and limited I-f.
cfg.Ts=50e-6;
cfg.Theta0=0;                 % electrical rad, initial SOFTWARE field angle
cfg.AlignCurrent=2;           % A, virtual d-axis current during alignment
cfg.StartupCurrent=3;         % A, rotating stator current-vector magnitude
cfg.FinalOmega=250;           % electrical rad/s, unsigned ramp endpoint
cfg.FlyingCaptureTime=0.03;   % s, zero-current capture opportunity
cfg.PrealignTime=0.06;        % s, hold at -direction*pi/2
cfg.PrealignRampTime=0.03;    % s, current rise 0 -> AlignCurrent
cfg.AlignTime=0.08;           % s, rotate field to zero and hold
cfg.AlignRampTime=0.04;       % s, -direction*pi/2 -> 0
cfg.OmegaRampTime=0.35;       % s, 0 -> direction*FinalOmega
cfg.CurrentRampTime=0.05;     % s, AlignCurrent -> StartupCurrent
cfg.MinCaptureOmega=150;     % electrical rad/s, permits acquisition checks
cfg.MaxIFTime=0.8;            % s, ramp+waiting timeout
cfg=refresh_startup_parameters(cfg);
end
