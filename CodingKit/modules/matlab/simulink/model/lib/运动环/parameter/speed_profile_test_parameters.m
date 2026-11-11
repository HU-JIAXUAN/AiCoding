function cfg=speed_profile_test_parameters()
%SPEED_PROFILE_TEST_PARAMETERS Default demonstration with reversal and clearing.
cfg.Ts=50e-6;cfg.Duration=.5;cfg.ReferenceInitial=0;cfg.Reference=10;cfg.CommandTime=.02;
cfg.ReverseReference=-10;cfg.ReverseTime=.2;cfg.DisableStart=.28;cfg.DisableEnd=.32;cfg.ResetTime=.4;
end
