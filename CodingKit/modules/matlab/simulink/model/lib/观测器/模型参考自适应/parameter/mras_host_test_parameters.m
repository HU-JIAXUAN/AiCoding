function cfg=mras_host_test_parameters()
%MRAS_HOST_TEST_PARAMETERS Physical fixture and comparison limits for host code.
base=mras_test_parameters();
cfg.Duration=.1;cfg.CheckStart=.08; % s; 2001 samples with the default 50 us
cfg.InitialAngle=base.InitialAngle; % electrical rad
cfg.ElectricalSpeed=base.ElectricalSpeed; % electrical rad/s, signed
cfg.Id=base.Id;cfg.Iq=base.Iq; % A, constant true dq trajectory
cfg.Direction=base.Direction; % +1 or -1, explicit direction prior
cfg.AngleRmsLimit=base.AngleRmsLimit; % electrical rad
cfg.SpeedRmsLimit=base.SpeedRmsLimit; % electrical rad/s
cfg.ValidFractionMinimum=base.ValidFractionMinimum;
cfg.MexDoubleRelativeLimit=1e-8;
cfg.MexSingleRelativeLimit=1e-3;
cfg.SilDoubleRelativeLimit=1e-8;
end
