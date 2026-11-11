function cfg = pmsm_parameters()
%PMSM_PARAMETERS Synthetic SI fixture, not identified hardware parameters.
cfg.Rs = 0.5;             % ohm, per phase
cfg.Ld = 1e-3;            % H
cfg.Lq = 1.2e-3;          % H
cfg.Flux = 0.035;         % Wb, permanent magnet flux linkage
cfg.PolePairs = 4;
cfg.J = 5e-4;             % kg*m^2, motor plus rigid load
cfg.B = 1e-4;             % N*m*s/rad
cfg.Id0 = 0; cfg.Iq0 = 0; % A
cfg.Speed0 = 0;           % rad/s, mechanical
cfg.Position0 = 0;        % rad, mechanical
end
