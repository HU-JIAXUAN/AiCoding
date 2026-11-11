function cfg=current_loop_test_parameters()
%CURRENT_LOOP_TEST_PARAMETERS Editable dq reference, speed, enable and reset.
control=current_parameters();cfg.Ts=control.Ts;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.IdReference=0;cfg.IqReference=2;cfg.CommandTime=0.003;cfg.ElectricalSpeed=0;cfg.Enable=1;cfg.Reset=0;
sample=(0:round(cfg.Duration/cfg.Ts))';
cfg.Inputs=[cfg.IdReference*ones(size(sample)),cfg.IqReference*double(sample>=round(cfg.CommandTime/cfg.Ts)), ...
    cfg.ElectricalSpeed*ones(size(sample)),cfg.Enable*ones(size(sample)),cfg.Reset*ones(size(sample))];
end
