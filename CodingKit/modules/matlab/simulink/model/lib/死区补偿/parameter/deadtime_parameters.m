function cfg = deadtime_parameters()
%DEADTIME_PARAMETERS Synthetic dead-time fixture, requires board calibration.
cfg.DeadTime = 2e-6;     % s
cfg.DeviceDrop = 0;      % V, omitted in gate-level cross-check
cfg.CurrentBlend = 0.1;  % A, compensation polarity blend around zero
cfg.ModelEnable = 0;
cfg.CompensationEnable = 0;
cfg.CompensationScale = 1;
cfg.SwitchingStep = 1e-7; % s, short single-leg test only
end
