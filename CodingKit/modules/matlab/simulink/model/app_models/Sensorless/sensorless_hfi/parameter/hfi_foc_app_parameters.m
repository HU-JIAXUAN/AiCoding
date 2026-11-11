function p=hfi_foc_app_parameters()
%HFI_FOC_APP_PARAMETERS Compose HFI startup, stock controllers and inverter.
p=hfi_startup_app_parameters();p.Test=hfi_foc_test_parameters();
p.Motor=hfi_plant_parameters(p.Test);p.Motor.Speed0=p.Test.InitialElectricalSpeed/p.Motor.PolePairs;
p.Motor=refresh_pmsm_hf_parameters(p.Motor);
p.HFI.Ts=p.Test.Ts;p.HFI=refresh_hfi_parameters(p.HFI);p.PLL=hfi_pll_parameters(p.HFI);
p.Probe.Ts=p.Test.Ts;p.Probe=refresh_hfi_probe_parameters(p.Probe);
p.Polarity.Ts=p.Test.Ts;p.Polarity=refresh_hfi_polarity_parameters(p.Polarity);
p.Current=current_parameters(p.Motor);p.Current.Ts=p.Test.Ts;
p.Inverter=inverter_parameters();p.Inverter.PwmTs=p.Test.Ts;
p.Inverter.LinearLimit=p.Inverter.Vdc/sqrt(3)*(1-2*p.Inverter.MinDuty);
p.Feedforward=feedforward_parameters();p.Feedforward.Enable=1;
p.Motion=motion_parameters(p.Motor);p.Motion.SpeedLimit=15;p.Motion.AccelerationLimit=40;
p.Profile=speed_profile_parameters();p.Profile.Ts=p.Test.Ts;
p.Profile.Minimum=-p.Motion.SpeedLimit;p.Profile.Maximum=p.Motion.SpeedLimit;
p.Profile.RisingRate=p.Motion.AccelerationLimit;p.Profile.FallingRate=p.Motion.AccelerationLimit;
p.Profile=refresh_speed_profile_parameters(p.Profile);
p.FOC.CurrentMax=2;p.FOC.Kt=1.5*p.Motor.PolePairs*p.Motor.Flux;
p.FOC.FrameCorrectionTolerance=1e-8;p.FOC.MaxMeasuredCurrent=8;
p.FOC.PositionLossTime=.002;
p.FOC.PositionLossSamples=round(p.FOC.PositionLossTime/p.Test.Ts);
assert(p.FOC.PositionLossSamples>=1 && abs(p.FOC.PositionLossSamples*p.Test.Ts-p.FOC.PositionLossTime)<1e-12);
p.FOC.SupervisorSettings=[p.FOC.MaxMeasuredCurrent;p.FOC.PositionLossSamples];
p.Reference=struct('SpeedTs',p.Motion.Ts,'SpeedKp',p.Motion.Kp*p.FOC.Kt, ...
    'SpeedKi',p.Motion.Ki*p.FOC.Kt,'SpeedKaw',p.Motion.Kaw);
end
