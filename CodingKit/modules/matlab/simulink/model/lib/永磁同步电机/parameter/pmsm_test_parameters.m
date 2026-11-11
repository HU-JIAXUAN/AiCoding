function cfg=pmsm_test_parameters()
%PMSM_TEST_PARAMETERS Editable independent voltage and mechanical test inputs.
cfg.Ts=1e-4;cfg.Duration=0.03;cfg.SolverStep=5e-6;
cfg.Vd=2;cfg.Vq=0;cfg.ElectricalSpeed=0;cfg.MechanicalTorque=0;cfg.LoadTorque=0;
t=(0:round(cfg.Duration/cfg.Ts))';
cfg.Inputs=ones(size(t))*[cfg.Vd,cfg.Vq,cfg.ElectricalSpeed,cfg.MechanicalTorque,cfg.LoadTorque];
end
