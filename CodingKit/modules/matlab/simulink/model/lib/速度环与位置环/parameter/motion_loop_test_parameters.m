function cfg=motion_loop_test_parameters()
%MOTION_LOOP_TEST_PARAMETERS Editable outer-loop standalone input signals.
cfg.Ts=1e-4;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.PositionReference=1;cfg.PositionFeedback=0;cfg.SpeedReference=20;cfg.CommandTime=0.003;
cfg.SpeedFeedback=0;cfg.SpeedFeedforward=0;
sample=(0:round(cfg.Duration/cfg.Ts))';
cfg.Inputs=[cfg.PositionReference*ones(size(sample)),cfg.PositionFeedback*ones(size(sample)), ...
    cfg.SpeedReference*double(sample>=round(cfg.CommandTime/cfg.Ts)), ...
    cfg.SpeedFeedback*ones(size(sample)),cfg.SpeedFeedforward*ones(size(sample))];
end
