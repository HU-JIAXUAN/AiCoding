function cfg=refresh_speed_profile_parameters(cfg)
%REFRESH_SPEED_PROFILE_PARAMETERS Validate SI limits and derive per-tick steps.
assert(all(isfinite([cfg.Ts,cfg.Minimum,cfg.Maximum,cfg.RisingRate,cfg.FallingRate])));
assert(cfg.Ts>0 && cfg.Minimum<=0 && cfg.Maximum>=0 && cfg.Maximum>cfg.Minimum);
assert(cfg.RisingRate>0 && cfg.FallingRate>0);
cfg.RisingStep=cfg.RisingRate*cfg.Ts;cfg.FallingStep=cfg.FallingRate*cfg.Ts;
end
