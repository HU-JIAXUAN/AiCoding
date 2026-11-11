function cfg = experiment_parameters()
%EXPERIMENT_PARAMETERS Repeatable scenario; all values are simulation fixtures.
cfg.Step = 5e-6;         % s, plant solver step, distinct from controller Ts
cfg.LogTs = 1e-4;        % s, saved trace interval
cfg.Duration = 1.5;      % s, finite simulation duration
cfg.Mode = 2;            % 0=current, 1=speed, 2=position
cfg.UseInverter = 1;
cfg.UseTiming = 1;
cfg.UseMechanical = 1;   % 0 uses imposed electrical speed
cfg.ImposedElectricalSpeed = 0; % rad/s
cfg.IdReference = 0; cfg.IqReference = 2; % A
cfg.IqInitial = 0;       % A, value before CommandTime
cfg.SpeedReference = 40; % rad/s
cfg.SpeedInitial = 0;    % rad/s
cfg.PositionReference = 1; % rad
cfg.PositionInitial = 0; % rad
cfg.CommandTime = 0.05;  % s
cfg.LoadTorque = 0.1;    % N*m, signed opposing torque
cfg.LoadTime = 0.35;     % s
cfg.Enable = 1; cfg.Reset = 0;
end
