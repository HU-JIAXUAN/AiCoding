function cfg = current_parameters(motor)
%CURRENT_PARAMETERS PI design fixture: pole cancellation at 500 Hz.
if nargin == 0, motor = pmsm_parameters(); end
cfg.Ts = 1e-4;
cfg.BandwidthHz = 500;
cfg.Kpd = motor.Ld*2*pi*cfg.BandwidthHz;
cfg.Kpq = motor.Lq*2*pi*cfg.BandwidthHz;
cfg.Kid = motor.Rs*2*pi*cfg.BandwidthHz;
cfg.Kiq = cfg.Kid;
cfg.Kaw = 1000;          % 1/s, external consistent voltage residual
end
