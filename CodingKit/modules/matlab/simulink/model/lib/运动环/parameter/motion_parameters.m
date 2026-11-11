function cfg = motion_parameters(motor)
%MOTION_PARAMETERS Rigid-load speed PI and position P demonstration tuning.
if nargin == 0, motor = pmsm_parameters(); end
cfg.Ts = 1e-3;           % s, outer-loop update interval
cfg.NaturalFrequency = 20; % rad/s
cfg.Damping = 0.9;
cfg.Kt = 1.5*motor.PolePairs*motor.Flux; % N*m/A at id=0
cfg.Kp = (2*cfg.Damping*cfg.NaturalFrequency*motor.J-motor.B)/cfg.Kt;
cfg.Ki = motor.J*cfg.NaturalFrequency^2/cfg.Kt;
cfg.Kaw = 20;            % 1/s
cfg.PositionKp = 8;      % 1/s
cfg.SpeedLimit = 80;     % rad/s
cfg.AccelerationLimit = 200; % rad/s^2, slew-limited speed command
cfg.CurrentLimit = 8;    % A, peak q-axis current, id=0 baseline
end
