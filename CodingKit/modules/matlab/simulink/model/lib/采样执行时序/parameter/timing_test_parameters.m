function cfg=timing_test_parameters()
%TIMING_TEST_PARAMETERS Editable sample/hold test steps.
timing=timing_parameters();cfg.Ts=timing.Ts;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.FirstStepTime=0.003;cfg.FirstAmplitude=1;cfg.SecondStepTime=0.005;cfg.SecondAmplitude=2;
sample=(0:round(cfg.Duration/cfg.Ts))';
cfg.Inputs=[cfg.FirstAmplitude*double(sample>=round(cfg.FirstStepTime/cfg.Ts)), ...
    cfg.SecondAmplitude*double(sample>=round(cfg.SecondStepTime/cfg.Ts))];
end
