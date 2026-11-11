function cfg=pmsm_bridge_parameters()
%PMSM_BRIDGE_PARAMETERS Linear PMSM and stiff-DC bridge for physical MIL.
% No measured board/device identification is implied by these nominal values.
cfg=pmsm_parameters();bus=inverter_parameters();
cfg.Ts=5e-6;cfg.Vdc=bus.Vdc;
cfg.DiodeVf=0.7;cfg.DiodeRon=0.01; % illustrative PWL diode, zero off leakage
cfg.MechanicalEnabled=1;          % 1 free rotor; 0 prescribed constant speed
cfg.CurrentTolerance=1e-9;cfg.VoltageTolerance=1e-8;
cfg.MaxCurrent=200;cfg.MaxSpeed=1000;cfg.MaxAngleStep=0.1;
cfg=refresh_pmsm_bridge_parameters(cfg);
end
