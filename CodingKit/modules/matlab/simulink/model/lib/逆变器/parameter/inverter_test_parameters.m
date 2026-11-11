function cfg=inverter_test_parameters()
%INVERTER_TEST_PARAMETERS Editable rotating alpha/beta voltage fixture.
cfg.Ts=1e-4;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.VoltageAmplitude=20;cfg.FrequencyHz=50;cfg.InitialPhase=0;
time=(0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;phase=cfg.InitialPhase+2*pi*cfg.FrequencyHz*time;
cfg.Inputs=cfg.VoltageAmplitude*[cos(phase),sin(phase)];
end
