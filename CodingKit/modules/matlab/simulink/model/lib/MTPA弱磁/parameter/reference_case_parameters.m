function p = reference_case_parameters(model)
%REFERENCE_CASE_PARAMETERS Assemble defaults without altering model state.
if strcmp(model,'MTPAFWMotor')
    module=fileparts(fileparts(mfilename('fullpath')));
    modelRoot=fileparts(fileparts(module));
    addpath(fullfile(modelRoot,'app_models','Sensor','mtpa_fw','parameter'));
    p=mtpa_fw_app_parameters();
    return
end
p.pmsmCfg=pmsm_parameters();p.currentCfg=current_parameters(p.pmsmCfg);
p.inverterCfg=inverter_parameters();p.timingCfg=timing_parameters();
p.motionCfg=motion_parameters(p.pmsmCfg);p.feedforwardCfg=feedforward_parameters();
p.deadtimeCfg=deadtime_parameters();p.experimentCfg=experiment_parameters();
p.refCfg=mtpa_fw_parameters(p.pmsmCfg,p.inverterCfg,p.motionCfg);
p.refTestCfg=reference_test_parameters();
end
