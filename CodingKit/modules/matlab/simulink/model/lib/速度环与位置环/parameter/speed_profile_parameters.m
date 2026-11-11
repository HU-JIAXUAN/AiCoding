function cfg=speed_profile_parameters()
%SPEED_PROFILE_PARAMETERS Discrete speed bounds, slew and explicit state reset.
cfg.Ts=50e-6;cfg.Minimum=-15;cfg.Maximum=15;
cfg.RisingRate=40;cfg.FallingRate=40;
cfg=refresh_speed_profile_parameters(cfg);
end
