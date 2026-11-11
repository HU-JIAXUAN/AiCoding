function cfg=feedforward_test_parameters()
%FEEDFORWARD_TEST_PARAMETERS Editable currents, speed and compensation switch.
cfg.Ts=1e-4;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.Id=1;cfg.Iq=2;cfg.ElectricalSpeed=1000;cfg.Enable=1;
sample=(0:round(cfg.Duration/cfg.Ts))';cfg.Inputs=ones(size(sample))*[cfg.Id,cfg.Iq,cfg.ElectricalSpeed];
end
