function cfg=open_loop_drive_parameters(kind)
%OPEN_LOOP_DRIVE_PARAMETERS Software field oscillator and startup interlock.
if nargin==0,kind=1;end % 1 I-f current magnitude; 2 V/f voltage magnitude
cfg.Ts=1/16000;cfg.Kind=kind;cfg.MaximumFrequency=80;cfg.FrequencySlew=40;
cfg.ObserveTime=.05;cfg.StartVoltageMaximum=.25;cfg.StartCurrentMaximum=.2;
cfg.ObserveTimeout=.5;cfg.AlignTime=.25;cfg.AlignRampTime=.1;
cfg.AlignAmplitude=2;cfg.RunAmplitude=3;cfg.AmplitudeSlew=40;
cfg.VfSlope=2*pi*.035;cfg.VfBoost=.5;cfg.VoltageFraction=.96/sqrt(3);
cfg.CurrentTrip=12;cfg.Theta0=0;
if kind==2,cfg.AlignAmplitude=.5;cfg.AmplitudeSlew=50;end
cfg=refresh_open_loop_drive_parameters(cfg);
end
