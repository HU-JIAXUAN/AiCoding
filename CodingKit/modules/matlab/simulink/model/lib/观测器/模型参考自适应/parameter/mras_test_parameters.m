function cfg=mras_test_parameters()
%MRAS_TEST_PARAMETERS Independent continuous dq-balance fixture defaults.
cfg.Duration=.5;cfg.InitialAngle=.7;cfg.ElectricalSpeed=600;
cfg.Id=0;cfg.Iq=2;cfg.Direction=1;cfg.Enable=1;cfg.Reset=0;
cfg.NoiseRms=0;cfg.NoiseSeed=42;cfg.CheckStart=.35;
cfg.CurrentDelay=0; % optional one-sample current age, no voltage-age compensation
cfg.AngleRmsLimit=.08;cfg.SpeedRmsLimit=8;cfg.ValidFractionMinimum=.95;
end
