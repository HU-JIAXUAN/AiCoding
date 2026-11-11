function cfg=sensorless_foc_validation_parameters()
%SENSORLESS_FOC_VALIDATION_PARAMETERS Cases and units for the first App campaign.
cfg.Cases={'positive','negative','initial_opposite','high_inertia','resistance_mismatch', ...
    'lower_bus','observer_loss','current_alignment_baseline'};
cfg.NegativeSpeed=-80;cfg.NegativeLoad=-0.1;
cfg.InitialElectricalAngle=pi/2;cfg.InertiaFactor=2;cfg.ResistanceFactor=1.2;
% Inject only after the 0.9 s load step has settled. The same 0.2 s
% steady-state window and limits as the healthy cases remain in effect.
cfg.LowBusVoltage=36;cfg.ObserverLossTime=1.8;cfg.FaultCaseDuration=2;
cfg.SteadyWindow=0.2;cfg.MaxAngleRms=0.12;cfg.MaxSpeedError=0.5;
cfg.MaxHealthyCurrent=8.8;cfg.MaxCurrentReference=8;
end
