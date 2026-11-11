function cfg=ukf_parameters()
%UKF_PARAMETERS Compose the same physical/covariance defaults as the EKF.
cfg=ekf_parameters();cfg.Alpha=1;cfg.Beta=2;cfg.Kappa=0;
cfg.StateScales=[1;1;100;1]; % A, A, electrical rad/s, electrical rad
cfg.InitialJitter=1e-12;cfg.MaximumJitter=1e-8;cfg.MaximumJitterAttempts=5;
cfg.MinimumAngleResultant=1e-6;cfg.MaximumSigmaAngleDeviation=pi/2-1e-3;
cfg=refresh_ukf_parameters(cfg);
end
