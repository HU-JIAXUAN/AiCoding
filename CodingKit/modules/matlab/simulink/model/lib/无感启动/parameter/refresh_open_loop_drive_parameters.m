function cfg=refresh_open_loop_drive_parameters(cfg)
%REFRESH_OPEN_LOOP_DRIVE_PARAMETERS Validate SI values and pack kernel settings.
assert(cfg.MaximumFrequency*cfg.Ts<.5,'The software field frequency exceeds Nyquist.');
assert(ismember(cfg.Kind,[1,2])&&cfg.Ts>0&&cfg.MaximumFrequency>0&&cfg.FrequencySlew>0);
assert(cfg.AlignAmplitude>=0&&cfg.RunAmplitude>=0&&cfg.AmplitudeSlew>0);
assert(cfg.VfSlope>=0&&cfg.VfBoost>=0&&cfg.VoltageFraction>0&&cfg.VoltageFraction<=1/sqrt(3));
assert(cfg.CurrentTrip>0&&cfg.StartVoltageMaximum>0&&cfg.StartCurrentMaximum>=0);
cfg.ObserveTicks=ceil(cfg.ObserveTime/cfg.Ts);cfg.ObserveTimeoutTicks=ceil(cfg.ObserveTimeout/cfg.Ts);
cfg.AlignTicks=ceil(cfg.AlignTime/cfg.Ts);cfg.AlignRampTicks=ceil(cfg.AlignRampTime/cfg.Ts);
assert(cfg.ObserveTicks>=1&&cfg.ObserveTimeoutTicks>cfg.ObserveTicks);
assert(cfg.AlignTicks>=cfg.AlignRampTicks&&cfg.AlignRampTicks>=1);
cfg.Vector=[cfg.Ts;cfg.Kind;cfg.MaximumFrequency;cfg.FrequencySlew;cfg.ObserveTicks; ...
    cfg.StartVoltageMaximum;cfg.StartCurrentMaximum;cfg.ObserveTimeoutTicks; ...
    cfg.AlignTicks;cfg.AlignRampTicks;cfg.AlignAmplitude;cfg.RunAmplitude; ...
    cfg.AmplitudeSlew;cfg.VfSlope;cfg.VfBoost;cfg.VoltageFraction;cfg.CurrentTrip;cfg.Theta0];
assert(all(isfinite(cfg.Vector)));cfg.State0=[0;0;cfg.Theta0;0;0;0;0;0];
end
