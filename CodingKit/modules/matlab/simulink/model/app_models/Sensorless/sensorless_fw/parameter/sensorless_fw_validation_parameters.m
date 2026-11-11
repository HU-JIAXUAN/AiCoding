function limits=sensorless_fw_validation_parameters()
%SENSORLESS_FW_VALIDATION_PARAMETERS Declared nominal MIL acceptance limits.
% These are fixture criteria, not a measured motor/board specification.
limits.SteadyWindow=0.3;          % s, tail interval after high-speed settling
limits.AngleRmsMax=0.05;          % electrical rad
limits.SpeedErrorRmsMax=3;        % mechanical rad/s
limits.ValidFractionMin=0.99;
limits.AutoFractionMin=0.99;
limits.CurrentOvershoot=1;        % A above allocator's dq vector limit
limits.ReferenceTolerance=1e-9;  % A, algebraic allocator current check
limits.VoltageTolerance=1e-8;    % V, declared steady-model feasibility check
limits.KclTolerance=1e-9;        % A
limits.WeakeningIdMinimum=0.1;    % A magnitude, commanded and physical d current
limits.WeakeningFractionMin=0.9;
limits.DutyTolerance=1e-10;
end
