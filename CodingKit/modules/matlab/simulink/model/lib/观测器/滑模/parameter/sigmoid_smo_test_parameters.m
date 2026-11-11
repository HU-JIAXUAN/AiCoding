function cfg=sigmoid_smo_test_parameters()
%SIGMOID_SMO_TEST_PARAMETERS Default independent SPMSM waveform and tolerances.
cfg.Duration=.3;cfg.Omega=200;cfg.InitialTheta=.4;cfg.Iq=2;
cfg.WindowStart=.25;cfg.MaximumAngleError=.08;cfg.MaximumSpeedRms=15;
cfg.MinimumValidFraction=.95;cfg.Seed=23;
cfg.HighOmega=600;cfg.AccelerationStartOmega=100;cfg.Acceleration=2000;cfg.AccelerationEnd=.2;
cfg.ResistanceScale=1.2;cfg.InductanceScale=1.2;
cfg.VoltageNoiseStd=.02;cfg.CurrentNoiseStd=.005;cfg.HighCurrentNoiseStd=.01;
cfg.ResetStart=.15;cfg.ResetDuration=.0001;cfg.DisableStart=.1;cfg.DisableEnd=.15;
cfg.ReversalOmega=300;cfg.ReversalStart=.1;cfg.ReversalDuration=.1;
cfg.LowOmega=5;cfg.OverOmega=1000;cfg.FaultStart=.12;cfg.FaultDuration=.0001;cfg.FaultVerifyDelay=.001;
cfg.FaultCurrentExcess=1;cfg.InstanceGain=45;cfg.InstanceSlope=.8;cfg.InstanceTheta=1.1;
end
