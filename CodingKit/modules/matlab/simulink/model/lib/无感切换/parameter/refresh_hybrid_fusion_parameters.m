function cfg=refresh_hybrid_fusion_parameters(cfg)
%REFRESH_HYBRID_FUSION_PARAMETERS Validate physical limits and derive sample fields.
values=[cfg.Ts,cfg.LowOmega,cfg.HighOmega,cfg.LowMaxOmega,cfg.HighMinOmega, ...
    cfg.MaxPhaseGap,cfg.MaxSpeedGap,cfg.QualificationTime,cfg.LossTime, ...
    cfg.BlendTime,cfg.InjectionRampTime,cfg.InjectionResumeOmega,cfg.InjectionOffOmega, ...
    cfg.PhaseCorrectionRate,cfg.MaxPhaseInnovation,cfg.MinInjectionScale];
assert(all(isfinite(values)) && all(values>0));
assert(cfg.HighMinOmega<cfg.LowOmega && cfg.LowOmega<cfg.HighOmega);
assert(cfg.HighOmega<cfg.InjectionResumeOmega && cfg.InjectionResumeOmega<cfg.InjectionOffOmega);
assert(cfg.InjectionOffOmega<cfg.LowMaxOmega);
assert(cfg.MaxPhaseGap<pi/2 && cfg.MaxPhaseInnovation<pi/2 && cfg.MinInjectionScale<1);
assert(ismember(cfg.AllowHighStart,[0,1]));
cfg.QualificationSamples=max(1,ceil(cfg.QualificationTime/cfg.Ts));
cfg.LossSamples=max(1,ceil(cfg.LossTime/cfg.Ts));
cfg.Vector=[cfg.Ts;cfg.LowOmega;cfg.HighOmega;cfg.LowMaxOmega;cfg.MaxPhaseGap; ...
    cfg.MaxSpeedGap;cfg.QualificationSamples;cfg.LossSamples; ...
    min(1,cfg.Ts/cfg.BlendTime);min(1,cfg.Ts/cfg.InjectionRampTime); ...
    cfg.InjectionResumeOmega;cfg.InjectionOffOmega;cfg.PhaseCorrectionRate; ...
    cfg.MaxPhaseInnovation;cfg.AllowHighStart;cfg.HighMinOmega;cfg.MinInjectionScale];
cfg.State0=zeros(20,1);cfg.State0(4)=1;cfg.State0(18)=1;
% theta,omega,beta,injection,flip,lowN,highN,lossN,acquired,fault,
% lastLowTheta,lastLowOmega,lastHighTheta,lastHighOmega,lowSeen,highSeen,
% lowBranchReady,injectionTarget,lowBadAge,highBadAge. UnitDelay owns all states.
end
