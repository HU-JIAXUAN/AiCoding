function cfg = clarke_park_parameters()
%CLARKE_PARK_PARAMETERS Current-vector MIL fixture, not motor tuning.
cfg.Ts = 1.0e-4;
cfg.Duration = 0.1;
cfg.Amplitude = 5.0;
cfg.FrequencyHz = 50.0;
cfg.InitialAngleRad = 0.3;
cfg.AngleOffsetRad = 0.0;
cfg.UseIndependentInverse = 0;
cfg.ZeroSequenceGain = 1.0;
cfg.RandomSeed = 2026;
end
