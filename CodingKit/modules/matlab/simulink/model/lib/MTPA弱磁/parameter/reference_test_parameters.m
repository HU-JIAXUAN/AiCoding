function cfg = reference_test_parameters()
%REFERENCE_TEST_PARAMETERS Finite repeatable component and motor scenarios.
cfg.Duration=0.25;
cfg.VoltageDemandTime=0.02; % s, uniform input event
cfg.Enable=1;
cfg.Reset=0;
cfg.TorqueReference=0.2;    % N*m
cfg.TorqueInitial=0;
cfg.ElectricalSpeed=800;   % rad/s, component/imposed-speed bench
cfg.Vdc=48;
cfg.VoltageDemand=28;      % V, synthetic pre-limit demand in component bench
end
