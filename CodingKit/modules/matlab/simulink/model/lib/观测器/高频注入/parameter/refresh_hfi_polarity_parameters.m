function cfg=refresh_hfi_polarity_parameters(cfg)
%REFRESH_HFI_POLARITY_PARAMETERS Derive exact sample counts and local settings.
assert(cfg.Ts>0 && cfg.PulseVoltage>0 && cfg.PulseTime>=cfg.Ts);
assert(cfg.AxisStableTime>=cfg.Ts && cfg.SettleTime>=cfg.Ts && cfg.DecayStableTime>=cfg.Ts);
assert(cfg.AxisTimeout>cfg.AxisStableTime && cfg.StageTimeout>cfg.PulseTime && cfg.TotalTimeout>cfg.AxisTimeout);
assert(cfg.CurrentDecay>0 && cfg.MaxCurrent>cfg.CurrentDecay && cfg.MaxAxisSpeed>0);
assert(cfg.MinPeakDifference>0 && cfg.MinRelativeDifference>0 && cfg.MinRelativeDifference<1);
assert(cfg.MinPulseDose>0 && cfg.MaxDoseMismatch>0 && cfg.MaxDoseMismatch<1);
assert(cfg.MaxCrossDoseFraction>0 && cfg.MaxCrossDoseFraction<1 && cfg.MinPulseVoltage>0 && cfg.SpeedFilterTime>0);
times=[cfg.PulseTime,cfg.AxisStableTime,cfg.SettleTime,cfg.DecayStableTime,cfg.AxisTimeout,cfg.StageTimeout,cfg.TotalTimeout];
samples=round(times/cfg.Ts);assert(all(abs(samples*cfg.Ts-times)<1e-12),'Times must lie on the Ts grid.');
cfg.PulseSamples=samples(1);cfg.AxisStableSamples=samples(2);cfg.SettleSamples=samples(3);
cfg.DecayStableSamples=samples(4);cfg.AxisTimeoutSamples=samples(5);cfg.StageTimeoutSamples=samples(6);cfg.TotalTimeoutSamples=samples(7);
cfg.SpeedA=exp(-cfg.Ts/cfg.SpeedFilterTime);
cfg.Settings=[cfg.Ts;cfg.PulseVoltage;samples(:);cfg.CurrentDecay;cfg.MaxCurrent;cfg.MaxAxisSpeed; ...
    cfg.MinPeakDifference;cfg.MinRelativeDifference;cfg.MinPulseDose;cfg.MaxDoseMismatch;cfg.MaxCrossDoseFraction;cfg.MinPulseVoltage;cfg.SpeedA];
cfg.InitialState=zeros(19,1);
end
