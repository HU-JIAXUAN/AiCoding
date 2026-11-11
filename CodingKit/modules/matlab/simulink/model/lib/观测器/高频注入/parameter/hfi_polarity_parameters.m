function cfg=hfi_polarity_parameters()
%HFI_POLARITY_PARAMETERS Axis-first dual pulse with measured voltage doses.
cfg.Ts=50e-6;cfg.PulseVoltage=4;cfg.PulseTime=.001;
cfg.AxisStableTime=.005;cfg.SettleTime=.005;cfg.DecayStableTime=.0005;
cfg.AxisTimeout=.2;cfg.StageTimeout=.05;cfg.TotalTimeout=.35;
cfg.CurrentDecay=.03;cfg.MaxCurrent=6;cfg.MaxAxisSpeed=2;
cfg.MinPeakDifference=.1;cfg.MinRelativeDifference=.03;
cfg.MinPulseDose=.001;cfg.MaxDoseMismatch=.05;cfg.MaxCrossDoseFraction=.1;
cfg.MinPulseVoltage=.5;cfg.SpeedFilterTime=.005;
cfg=refresh_hfi_polarity_parameters(cfg);
end
