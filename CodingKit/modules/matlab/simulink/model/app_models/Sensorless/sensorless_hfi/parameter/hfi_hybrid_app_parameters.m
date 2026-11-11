function p=hfi_hybrid_app_parameters()
%HFI_HYBRID_APP_PARAMETERS Compose physical HFI, IPMSM EEMF and shared fusion.
p=hfi_foc_app_parameters();p.Test=hfi_hybrid_test_parameters();
p.Motor=hfi_plant_parameters(p.Test);p.Motor.Speed0=p.Test.InitialElectricalSpeed/p.Motor.PolePairs;
p.Motor=refresh_pmsm_hf_parameters(p.Motor);
p.Current=current_parameters(p.Motor);p.Current.Ts=p.Test.Ts;
p.Motion=motion_parameters(p.Motor);p.Motion.SpeedLimit=35;p.Motion.AccelerationLimit=40;
p.Motion.NaturalFrequency=30; % rad/s; reduce ramp-end speed overshoot before restart
p.Motion.Kp=(2*p.Motion.Damping*p.Motion.NaturalFrequency*p.Motor.J-p.Motor.B)/p.Motion.Kt;
p.Motion.Ki=p.Motor.J*p.Motion.NaturalFrequency^2/p.Motion.Kt;
p.Profile.Ts=p.Test.Ts;p.Profile.Minimum=-p.Motion.SpeedLimit;p.Profile.Maximum=p.Motion.SpeedLimit;
p.Profile.RisingRate=p.Motion.AccelerationLimit;p.Profile.FallingRate=p.Motion.AccelerationLimit;
p.Profile=refresh_speed_profile_parameters(p.Profile);
p.Reference=struct('SpeedTs',p.Motion.Ts,'SpeedKp',p.Motion.Kp*p.FOC.Kt, ...
    'SpeedKi',p.Motion.Ki*p.FOC.Kt,'SpeedKaw',p.Motion.Kaw);
p.EMF=emf_parameters('ipmsm');p.EMF.Ts=p.Test.Ts;
p.EMF.Rs=p.Motor.Rs;p.EMF.Ld=p.Motor.Ld;p.EMF.Lq=p.Motor.Lq;
p.EMF.Flux=p.Motor.Flux;p.EMF.PolePairs=p.Motor.PolePairs;
p.EMFPLL=angle_tracking_parameters();p.EMFPLL.Ts=p.Test.Ts;p.EMFPLL.MinMagnitude=p.EMF.MinEmf;
p.Fusion=hybrid_fusion_parameters();p.Fusion.Ts=p.Test.Ts;
p.Fusion.AllowHighStart=0; % first physical assembly acquires polarity through HFI
p.Fusion=refresh_hybrid_fusion_parameters(p.Fusion);
p.Hybrid.InitialDirection=1;p.Hybrid.DirectionThreshold=5;
p.Hybrid.DirectionSettings=[p.Hybrid.InitialDirection;p.Hybrid.DirectionThreshold];
end
