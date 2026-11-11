function cfg = timing_parameters()
%TIMING_PARAMETERS Explicit MIL sample/hold and integer-tick delay fixture.
cfg.Ts = 1e-4;           % s, current/angle sample interval
cfg.FeedbackTicks = 1;   % additional full sample ticks after sampling
cfg.ActuationTicks = 1;  % full control ticks before command application
end
