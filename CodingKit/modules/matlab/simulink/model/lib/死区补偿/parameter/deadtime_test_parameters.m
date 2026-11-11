function cfg=deadtime_test_parameters()
%DEADTIME_TEST_PARAMETERS Editable phase-current waveform and model switches.
cfg.Ts=1e-4;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.CurrentAmplitude=3;cfg.FrequencyHz=50;cfg.InitialPhase=0;cfg.ModelEnable=1;cfg.CompensationEnable=1;
time=(0:round(cfg.Duration/cfg.Ts))'*cfg.Ts;phase=cfg.InitialPhase+2*pi*cfg.FrequencyHz*time;
cfg.Inputs=cfg.CurrentAmplitude*cos(phase+[0,-2*pi/3,2*pi/3]);
end
