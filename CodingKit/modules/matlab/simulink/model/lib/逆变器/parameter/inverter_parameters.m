function cfg = inverter_parameters()
%INVERTER_PARAMETERS Ideal two-level, isolated-neutral three-phase fixture.
cfg.Vdc = 48;            % V
cfg.MinDuty = 0.02;      % dimensionless symmetric duty reserve
cfg.PwmTs = 1e-4;        % s, 10 kHz
cfg.LinearLimit = cfg.Vdc/sqrt(3)*(1-2*cfg.MinDuty);
end
