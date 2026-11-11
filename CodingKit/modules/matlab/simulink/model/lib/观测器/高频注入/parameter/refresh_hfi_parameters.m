function cfg=refresh_hfi_parameters(cfg)
%REFRESH_HFI_PARAMETERS Validate the nominal high-frequency saliency model.
assert(cfg.Ts>0 && cfg.InjectionVoltage>0 && cfg.Ld>0 && cfg.Lq>cfg.Ld);
assert(cfg.Ld*cfg.Lq>cfg.CrossInductance^2 && cfg.MaxOmega>0);
assert(cfg.MinVoltageStep>0 && cfg.MaxCrossFraction>0 && cfg.MaxCrossFraction<1);
assert(cfg.MinResponse>0 && cfg.MaxResponse>cfg.MinResponse);
assert(cfg.MinInjectionScale>0 && cfg.MinInjectionScale<=1);
assert(cfg.DemodBandwidth>0 && cfg.DemodBandwidth<0.5/cfg.Ts);
cfg.DemodA=exp(-2*pi*cfg.DemodBandwidth*cfg.Ts);
assert(ismember(cfg.DemodFilterEnabled,[0,1]));
assert(ismember(cfg.UseMeasuredInverseAverage,[0,1]));
if ~cfg.DemodFilterEnabled,cfg.DemodA=0;end
cfg.InverseAverage=0.5*(cfg.Ld+cfg.Lq)/(cfg.Ld*cfg.Lq-cfg.CrossInductance^2);
cfg.CrossPhase=atan2(-2*cfg.CrossInductance,cfg.Lq-cfg.Ld);
cfg.InitialAxis=atan2(sin(cfg.InitialAxis),cos(cfg.InitialAxis));
cfg.InitialTrackerPhase=atan2(sin(2*cfg.InitialAxis),cos(2*cfg.InitialAxis));
cfg.AxisInitialState=[cfg.InitialAxis;cfg.InitialTrackerPhase];
cfg.DemodSettings=[cfg.Ts;cfg.InjectionVoltage;cfg.InverseAverage;cfg.CrossPhase; ...
    cfg.MinVoltageStep;cfg.MaxCrossFraction;cfg.MinResponse;cfg.MaxResponse;cfg.MinInjectionScale;cfg.DemodA;cfg.UseMeasuredInverseAverage];
cfg.TrackSettings=[cfg.InitialAxis;cfg.InitialTrackerPhase;cfg.MaxOmega];
end
