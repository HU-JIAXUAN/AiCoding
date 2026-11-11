function cfg = mtpa_fw_parameters(motor,inverter,motion)
%MTPA_FW_PARAMETERS SI current allocator defaults; synthetic MIL fixture.
if nargin<1,motor=pmsm_parameters();end
if nargin<2,inverter=inverter_parameters();end
if nargin<3,motion=motion_parameters(motor);end
cfg.MtpaEnable=1;
cfg.FwEnable=1;
cfg.CurrentMax=8;            % A, dq vector peak magnitude
cfg.IdMin=-7;               % A, illustrative demagnetization boundary
cfg.VoltageReserve=0.95;    % fraction of the existing inverter linear radius
cfg.FwVoltageMargin=0.2;    % V, weakening target below allocator voltage limit
cfg.MinDuty=inverter.MinDuty;
cfg.FwTs=1e-3;              % s, slower than current control
cfg.FilterTau=3e-3;         % s, voltage-demand filter
cfg.FwKi=50;                % A/(V*s), bounded integral weakening regulator
cfg.IdSlew=200;             % A/s, bounds each weakening-state increment
cfg.TablePoints=257;
cfg.SpeedTs=motion.Ts;
cfg.SpeedKp=motion.Kp*motion.Kt; % N*m/(rad/s)
cfg.SpeedKi=motion.Ki*motion.Kt; % N*m/rad
cfg.SpeedKaw=motion.Kaw;     % 1/s, allocator torque residual tracking
cfg=refresh_mtpa_tables(cfg,motor);
end
