function cfg=ekf_parameters()
%EKF_PARAMETERS Four-state SPMSM EKF model, covariance and qualification values.
cfg.Model=pmsm_sensorless_parameters();cfg.InitialOmega=300;cfg.InitialAngle=0;
cfg.InitialStd=[1;1;500;.5]; % A, A, electrical rad/s, electrical rad
cfg.ProcessNoiseDensity=[2;2;2000;1e-5]; % state variance per second
cfg.MeasurementStd=[.002;.002]; % A RMS
cfg.QualificationTime=.02;cfg.MinOmega=30;cfg.MinEmf=1;
cfg.MaxNIS=25;cfg.MaxThetaStd=.12;cfg.MaxOmegaStd=100;
cfg.AngleRateTimeConstant=.002;cfg.MaxRateMismatch=60;
cfg.MaxOmega=2000;cfg.MaxInputCurrent=100;cfg.MaxInputVoltage=1000;
cfg=refresh_kalman_parameters(cfg);
end
