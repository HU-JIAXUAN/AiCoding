function cfg = smo_parameters()
%SMO_PARAMETERS Boundary-layer SPMSM observer defaults, SI peak quantities.
cfg.Ts = 50e-6;       % s, must equal the connected PLL sample period
cfg.Rs = 0.5;         % ohm, per phase
cfg.L = 1e-3;         % H, SPMSM only: Ld = Lq = L
cfg.Flux = 0.035;     % Wb, used by the fixture, not by the observer update
cfg.PolePairs = 4;    % electrical / mechanical speed ratio
cfg.SlidingGain = 30; % V, z = K*sat((i_hat-i)/Boundary)
cfg.Boundary = 1;     % A, boundary-layer width
cfg.FilterHz = 600;   % Hz, first-order injection low-pass filter
cfg.MinEmf = 1;       % V, filtered EMF magnitude threshold
cfg.MinOmega = 30;    % electrical rad/s, validity qualification only
cfg.Compensate = 1;   % 0/1, discrete LPF phase correction
cfg = refresh_smo_parameters(cfg);
end
