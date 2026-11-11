function cfg=refresh_handover_parameters(cfg)
%REFRESH_HANDOVER_PARAMETERS Validate SI limits and derive sample-count fields.
values=[cfg.Ts,cfg.MinOmega,cfg.MaxSpeedGap,cfg.MaxPhaseGap,cfg.MaxResidual, ...
    cfg.CaptureTime,cfg.BlendTime,cfg.LossTime,cfg.MaxPhaseInnovation];
assert(all(isfinite(values)) && all(values>0));
assert(cfg.MaxPhaseGap<pi && cfg.MaxPhaseInnovation<pi);
assert(ismember(cfg.AllowFlying,[0,1]));
cfg.Samples=max(1,round([cfg.CaptureTime;cfg.BlendTime;cfg.LossTime]/cfg.Ts));
cfg.Vector=[cfg.Ts;cfg.MinOmega;cfg.MaxSpeedGap;cfg.MaxPhaseGap;cfg.MaxResidual; ...
    cfg.Samples;cfg.MaxPhaseInnovation;cfg.AllowFlying];
cfg.State0=zeros(9,1);
% State: mode,qualificationN,blendN,lossN,offset,lastTheta,fault,safeHat,safeOmega.
end
