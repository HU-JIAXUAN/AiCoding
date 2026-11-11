function p = mit_joint_parameters()
%MIT_JOINT_PARAMETERS Compose the repository's FOC fixture and MIT Mode inputs.
p = experiment_app_parameters();
p.mitCfg = struct( ...
    'UseMitMode', true, ...
    'GearRatio', 6, ...              % motor revolutions per joint revolution
    'Kt', p.motionCfg.Kt, ...        % N*m/A on the motor shaft at id = 0
    'CurrentLimit', p.motionCfg.CurrentLimit, ...
    'BusVoltageMax', 60, ...         % V, threshold for this 48 V fixture
    'FeedforwardMemory', 0.9, ...    % Katz firmware's discrete coefficient
    'Kp', 2, ...                    % N*m/rad at the joint
    'Kd', 0.12, ...                 % N*m*s/rad at the joint
    'PositionReference', 0.2, ...   % rad at the joint
    'VelocityReference', 0, ...     % rad/s at the joint
    'FeedforwardTorque', 0, ...     % N*m at the joint
    'LoadTorque', 0.18);            % N*m opposing torque at the joint
p.experimentCfg.Duration = 1.2;
end
