function cfg=refresh_ukf_parameters(cfg)
%REFRESH_UKF_PARAMETERS Refresh common correction and unscented prediction.
cfg=refresh_kalman_parameters(cfg);
assert(cfg.Alpha>=.05 && cfg.Alpha<=1 && cfg.Beta>=0 && cfg.Beta<=4 && cfg.Kappa>=0 && cfg.Kappa<=3);
assert(numel(cfg.StateScales)==4 && all(isfinite(cfg.StateScales)) && all(cfg.StateScales>0));
assert(cfg.InitialJitter>0 && cfg.MaximumJitter>=cfg.InitialJitter);
assert(cfg.MaximumJitterAttempts>=1 && cfg.MaximumJitterAttempts<=5 && cfg.MaximumJitterAttempts==floor(cfg.MaximumJitterAttempts));
assert(cfg.MinimumAngleResultant>0 && cfg.MinimumAngleResultant<1);
assert(cfg.MaximumSigmaAngleDeviation>0 && cfg.MaximumSigmaAngleDeviation<pi);
cfg.UnscentedSettings=[cfg.Settings;cfg.Alpha;cfg.Beta;cfg.Kappa;cfg.StateScales(:); ...
    cfg.InitialJitter;cfg.MaximumJitter;cfg.MaximumJitterAttempts;cfg.MinimumAngleResultant;cfg.MaximumSigmaAngleDeviation];
assert(numel(cfg.UnscentedSettings)==39 && all(isfinite(cfg.UnscentedSettings)));
c=cfg.Alpha^2*(4+cfg.Kappa);cfg.SigmaScale=c;
cfg.MeanWeights=[1-4/c;repmat(1/(2*c),8,1)];
cfg.CovarianceWeights=cfg.MeanWeights;cfg.CovarianceWeights(1)=cfg.CovarianceWeights(1)+1-cfg.Alpha^2+cfg.Beta;
end
