function cfg=refresh_startup_parameters(cfg)
%REFRESH_STARTUP_PARAMETERS Validate durations and derive integer sample counts.
assert(isfinite(cfg.Ts) && cfg.Ts>0);
assert(isfinite(cfg.Theta0) && abs(cfg.Theta0)<=pi);
assert(all(isfinite([cfg.AlignCurrent,cfg.StartupCurrent,cfg.FinalOmega,cfg.MinCaptureOmega])));
assert(cfg.AlignCurrent>0 && cfg.StartupCurrent>=cfg.AlignCurrent);
assert(cfg.FinalOmega>0 && cfg.MinCaptureOmega>0 && cfg.MinCaptureOmega<=cfg.FinalOmega);
durations=[cfg.FlyingCaptureTime,cfg.PrealignTime,cfg.PrealignRampTime, ...
    cfg.AlignTime,cfg.AlignRampTime,cfg.OmegaRampTime,cfg.CurrentRampTime,cfg.MaxIFTime];
assert(all(isfinite(durations)) && all(durations>=cfg.Ts));
assert(cfg.PrealignRampTime<=cfg.PrealignTime && cfg.AlignRampTime<=cfg.AlignTime);
assert(cfg.CurrentRampTime<=cfg.OmegaRampTime && cfg.OmegaRampTime<cfg.MaxIFTime);
cfg.Samples=max(1,round(durations/cfg.Ts));
cfg.Vector=[cfg.Ts;cfg.Theta0;cfg.AlignCurrent;cfg.StartupCurrent;cfg.FinalOmega; ...
    cfg.Samples(:);cfg.MinCaptureOmega];
% Vector indices: 1 Ts,2 theta0,3 Ialign,4 Istart,5 omegaFinal,
% 6 flyingN,7 prealignN,8 prealignRampN,9 alignN,10 alignRampN,
% 11 omegaRampN,12 currentRampN,13 maxIFN,14 minCaptureOmega.
cfg.State0=[0;0;cfg.Theta0;0;0];
end
