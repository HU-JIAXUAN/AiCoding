function limits=extension_foc_validation_parameters()
%EXTENSION_FOC_VALIDATION_PARAMETERS Common acceptance, fixed before App trials.
limits=sensorless_fw_validation_parameters();
limits.InputAgreementTolerance=1e-10;
limits.FrameAgreementTolerance=1e-10;
limits.BlendVoltageStepMax=2; % V per control sample in stationary frame
limits.PhysicalContinuityTolerance=1e-9;
end
