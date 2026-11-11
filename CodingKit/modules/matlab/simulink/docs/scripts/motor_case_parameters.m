function [p,stimulus]=motor_case_parameters(model)
%MOTOR_CASE_PARAMETERS Compose module-owned M-file defaults for existing benches.
initialize_motor_paths();
if strcmp(model,'MotorExperiment')
    p=experiment_app_parameters();
else
    p.pmsmCfg=pmsm_parameters();p.currentCfg=current_parameters(p.pmsmCfg);
    p.inverterCfg=inverter_parameters();p.timingCfg=timing_parameters();p.motionCfg=motion_parameters(p.pmsmCfg);
    p.feedforwardCfg=feedforward_parameters();p.deadtimeCfg=deadtime_parameters();p.experimentCfg=experiment_parameters();
end
switch char(model)
    case 'PMSMPlantTest',fixture=pmsm_test_parameters();
    case 'CurrentLoopTest',fixture=current_loop_test_parameters();
    case 'InverterTest',fixture=inverter_test_parameters();
    case 'TimingTest',fixture=timing_test_parameters();
    case 'MotionLoopTest',fixture=motion_loop_test_parameters();
    case 'FeedforwardTest'
        fixture=feedforward_test_parameters();p.feedforwardCfg.Enable=fixture.Enable;
    case 'DeadtimeTest'
        fixture=deadtime_test_parameters();p.deadtimeCfg.ModelEnable=fixture.ModelEnable;
        p.deadtimeCfg.CompensationEnable=fixture.CompensationEnable;
    case 'SwitchingLegTest',fixture=switching_leg_test_parameters();
    otherwise
        fixture=struct('Ts',p.currentCfg.Ts,'Duration',p.experimentCfg.Duration, ...
            'SolverStep',p.experimentCfg.Step,'Inputs',zeros(2,1));
end
assert(fixture.Ts>0 && fixture.Duration>0 && fixture.SolverStep>0);
assert(abs(fixture.Duration/fixture.Ts-round(fixture.Duration/fixture.Ts))<1e-9);
assert(all(isfinite(fixture.Inputs),'all'));
if ~strcmp(model,'SwitchingLegTest')
    p.currentCfg.Ts=fixture.Ts;p.timingCfg.Ts=fixture.Ts;
end
p.experimentCfg.Step=fixture.SolverStep;p.experimentCfg.LogTs=fixture.Ts;
p.fixtureCfg=fixture;
stimulus.time=[];stimulus.signals.values=fixture.Inputs;stimulus.signals.dimensions=size(fixture.Inputs,2);
end
