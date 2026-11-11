function cfg = angle_tracking_parameters()
%ANGLE_TRACKING_PARAMETERS Phase-input PLL defaults for the synthetic MIL fixture.
cfg.Ts = 50e-6;            % s, discrete update period
cfg.NaturalFrequency = 40; % Hz, starting design value, not measured bandwidth
cfg.Damping = 0.707;
wn = 2*pi*cfg.NaturalFrequency;
cfg.Kp = 2*cfg.Damping*wn;  % 1/s, phase-error proportional gain
cfg.Ki = wn^2;             % 1/s^2, phase-error integral gain
cfg.Kaw = 2*wn;            % 1/s, speed-saturation back calculation
cfg.OmegaMax = 1500;       % electrical rad/s
cfg.MinMagnitude = 0.5;    % same amplitude unit as input magnitude
cfg.LockError = 0.12;      % rad, phase-error qualification threshold
cfg.LockSamples = 100;     % consecutive samples, 5 ms with default Ts
cfg.Theta0 = 0;            % electrical rad
cfg.Omega0 = 0;            % electrical rad/s, integral initial value
end
