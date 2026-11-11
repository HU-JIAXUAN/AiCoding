function cfg = discrete_pid_parameters()
%DISCRETE_PID_PARAMETERS Dimensionless MIL fixture; not motor tuning values.
cfg.Kp = 1.2;
cfg.Ki = 8.0;
cfg.Kd = 0.0;
cfg.Tf = 0.01;
cfg.Ts = 1.0e-3;
cfg.UMin = -1.0;
cfg.UMax = 1.0;
cfg.X0 = 0.0;
cfg.Kaw = 20.0;
cfg.PlantTau = 0.08;
cfg.ClosedLoop = 1.0;
end
