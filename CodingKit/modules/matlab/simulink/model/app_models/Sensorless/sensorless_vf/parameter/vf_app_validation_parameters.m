function cfg=vf_app_validation_parameters()
%VF_APP_VALIDATION_PARAMETERS Scenarios, physical criteria and export budget.
cfg.Names={'default','reverse','initial_angle','reduced_bus','frequency_limit','load_step', ...
    'moving_forward_refused','moving_reverse_refused','current_trip','reset_refused','disable_refused','overload','voltage_shortage'};
cfg.SteadyWindow=.3;cfg.SpeedRmsLimit=3;cfg.CurrentRmsLimit=.25;cfg.PhaseTravelLimit=pi/2;
cfg.EquationResidualLimit=1e-6;cfg.DutyTolerance=1e-10;
cfg.InitialElectricalAngle=.5;cfg.ReducedBus=24;cfg.LimitFrequency=120;cfg.LimitDuration=3;
cfg.LoadStep=.1;cfg.MovingSpeed=30;cfg.RefusalDuration=.7;cfg.TripCurrent=.8;
cfg.EventTime=1.2;cfg.ResetDuration=.01;cfg.DisableDuration=.1;cfg.EventDuration=2.1;
cfg.CounterLoad=1;cfg.CounterLoadTime=.8;cfg.ShortageBus=6;
cfg.ExportMaximumRows=1601;cfg.StepSpeedMeanTolerance=.05;cfg.StepCurrentPeakTolerance=.05;
end
