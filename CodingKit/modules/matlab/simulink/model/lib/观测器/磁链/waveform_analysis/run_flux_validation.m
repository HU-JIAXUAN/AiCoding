function report=run_flux_validation()
%RUN_FLUX_VALIDATION Verify saved-model flux tracking, bias rejection and exits.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'), ...
    fullfile(lib,'相位跟踪','parameter'),fullfile(lib,'观测器','反电势','build_process'));
model='FluxObserverTest';open_system(fullfile(module,'src',[model,'.slx']));
names={'positive','negative','high_speed','acceleration','current_ramp','resistance_error', ...
    'voltage_bias','voltage_bias_no_washout','pure_integrator_bias','current_offset', ...
    'measurement_noise','flux_reference_error','zero_speed_enabled','low_speed_enabled', ...
    'disable','reset','reversal','wrap','leak_only','direction_column_ignored', ...
    'pure_integrator_unknown_initial','no_frequency_compensation','initial_angle_pi','initial_angle_minus_pi'};
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};cfg=flux_parameters();fixture=flux_test_parameters();
    sample=(0:round(fixture.Duration/cfg.Ts))';time=sample*cfg.Ts;one=ones(size(time));
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    omega=fixture.ElectricalSpeed*one;id=fixture.Id*one;iq=fixture.Iq*one;theta0=fixture.InitialAngle;
    switch name
        case 'negative',omega=-omega;
        case 'high_speed',omega(:)=600;
        case 'acceleration',omega=150+450*time/fixture.Duration;
        case 'current_ramp'
            ramp=min(max((time-0.3)/0.04,0),1);id=id-2*ramp;iq=iq+2*ramp;
        case {'voltage_bias_no_washout','leak_only'},cfg.DcEnable=0;
        case {'pure_integrator_bias','pure_integrator_unknown_initial'},cfg.LeakEnable=0;cfg.DcEnable=0;
        case 'no_frequency_compensation',cfg.MinCompOmega=1e5;cfg.FullCompOmega=2e5;
        case 'zero_speed_enabled',omega(:)=0;
        case 'low_speed_enabled',omega(:)=5;
        case 'reversal',omega(event(0.4))=-200;
        case 'wrap',theta0=3.12;
        case 'initial_angle_pi',theta0=pi-0.05;
        case 'initial_angle_minus_pi',theta0=-pi+0.05;
    end
    cfg=refresh_flux_parameters(cfg);pllCfg=angle_tracking_parameters();
    pllCfg.Ts=cfg.Ts;pllCfg.MinMagnitude=cfg.MinFlux;
    motor=struct('Ts',cfg.Ts,'Rs',cfg.Rs,'Ld',cfg.L,'Lq',cfg.L,'Flux',cfg.Flux,'MinOmega',cfg.MinOmega);
    if strcmp(name,'resistance_error'),motor.Rs=1.2*motor.Rs;end
    if strcmp(name,'flux_reference_error'),motor.Flux=0.8*motor.Flux;end
    [stimulus,truth]=emf_fixture(time,omega,theta0,id,iq,motor);
    switch name
        case {'voltage_bias','voltage_bias_no_washout','pure_integrator_bias'}
            stimulus.signals.values(:,1)=stimulus.signals.values(:,1)+0.1*event(0.2);
        case 'current_offset'
            stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+[0.02,-0.015];
        case 'measurement_noise'
            stream=RandStream('mt19937ar','Seed',42);
            stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+0.005*randn(stream,numel(time),2);
        case 'disable',stimulus.signals.values(event(0.45)&~event(0.5),6)=0;
        case 'reset',stimulus.signals.values(sample==round(0.45/cfg.Ts),7)=1;
        case 'direction_column_ignored'
            stream=RandStream('mt19937ar','Seed',43);stimulus.signals.values(:,5)=randi(stream,4,numel(time),1)-2;
    end
    input=Simulink.SimulationInput(model);input=input.setVariable('fluxCfg',cfg,'Workspace',model);
    input=input.setVariable('pllCfg',pllCfg,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    input=input.setModelParameter('StopTime',num2str(time(end),16));
    record=struct('name',name,'parameters',cfg,'pll',pllCfg,'fixture',fixture, ...
        'input',stimulus,'truth',truth,'time',time);
    fprintf('FLUX running %s\n',name);
    try
        timer=tic;output=sim(input);record.wall_time_s=toc(timer);trace=output.trace.signals.values;
        record.trace=trace;
        assert(ismatrix(trace) && size(trace,2)==24 && all(isfinite(trace),'all'));
        assert(isequal(trace(:,1:9),stimulus.signals.values));
        assert(max(abs(output.trace.time-time))<1e-12);
        tail=time>=fixture.Duration-0.2;validFraction=mean(trace(tail,12)>0.5);
        phaseError=atan2(sin(trace(:,10)-truth.theta),cos(trace(:,10)-truth.theta));
        angleRms=sqrt(mean(phaseError(tail).^2));speedRms=sqrt(mean((trace(tail,11)-omega(tail)).^2));
        rotorTruth=motor.Flux*[cos(truth.theta),sin(truth.theta)];
        fluxRms=sqrt(mean(sum((trace(tail,13:14)-rotorTruth(tail,:)).^2,2)));
        torqueTruth=1.5*cfg.PolePairs*motor.Flux*iq;
        torqueRms=sqrt(mean((trace(tail,18)-torqueTruth(tail)).^2));
        switch name
            case {'zero_speed_enabled','low_speed_enabled'}
                assert(validFraction==0 && all(trace(tail,23)==0));
            case 'flux_reference_error'
                assert(validFraction==0 && angleRms<0.15 && speedRms<3);
                assert(all(trace(tail,21)>cfg.MaxResidual));
            case 'voltage_bias_no_washout'
                assert(angleRms>0.01 && validFraction>0.9);
            case 'pure_integrator_bias'
                assert(angleRms>0.1 && max(trace(:,17))>2*cfg.Flux);
            case 'pure_integrator_unknown_initial'
                % Book 3.2.1: zero integration state is not the true initial flux.
                assert(angleRms>0.25 && fluxRms>0.01);
            case 'no_frequency_compensation'
                % Book 3.2.3: suppressing drift alone does not correct filter phase.
                assert(angleRms>0.25 && validFraction==0 && all(trace(tail,23)==0));
            otherwise
                assert(angleRms<0.15 && speedRms<3 && validFraction>0.95, ...
                    '%s angle %.6g speed %.6g valid %.6g',name,angleRms,speedRms,validFraction);
                if ismember(name,{'positive','negative','high_speed','leak_only'})
                    assert(fluxRms<1e-3 && torqueRms<0.005);
                end
        end
        if strcmp(name,'disable')
            off=event(0.45)&~event(0.5);assert(all(trace(off,[10:21,23])==0,'all'));
            rows=find(off);assert(all(trace(rows(2:end),22)==0));
        elseif strcmp(name,'reset')
            row=round(0.45/cfg.Ts)+1;assert(all(trace(row,[10:21,23])==0));assert(trace(row+1,22)==0);
        elseif strcmp(name,'direction_column_ignored')
            assert(isequal(trace(:,10:end),records.positive.trace(:,10:end)));
        end
        metric=struct('name',name,'angle_RMS_rad',angleRms,'speed_RMS_electrical_rad_s',speedRms, ...
            'flux_RMS_Wb',fluxRms,'torque_RMS_Nm',torqueRms,'valid_fraction',validFraction, ...
            'max_rotor_flux_Wb',max(trace(:,17)),'passed',true);
        record.metric=metric;metrics{test}=metric;records.(name)=record;
        fprintf('FLUX %s PASS angle=%.6g speed=%.6g valid=%.4g\n',name,angleRms,speedRms,validFraction);
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');
        save(fullfile(module,'waveform_analysis','failure.mat'),'record','-v7.3');
        rethrow(exception);
    end
end
assert(records.voltage_bias.metric.angle_RMS_rad<records.voltage_bias_no_washout.metric.angle_RMS_rad/10);
report=struct('release',version('-release'),'status','passed','tests',numel(names), ...
    'cases',[metrics{:}],'true_position_input',false,'direction_input',false,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','results.mat'),'records','report','-v7.3');
file=fopen(fullfile(module,'waveform_analysis','metrics.json'),'w');cleanup=onCleanup(@()fclose(file));
fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
for name={'positive','voltage_bias','voltage_bias_no_washout','pure_integrator_bias', ...
        'pure_integrator_unknown_initial','no_frequency_compensation','reversal'}
    exportCase(records.(name{1}),name{1},module);
end
disp(rmfield(report,'cases'));
end
function exportCase(record,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,1000]);cleanup=onCleanup(@()close(figureHandle));
tiledlayout(5,1);t=record.time;y=record.trace;
nexttile;plot(t,[atan2(sin(record.truth.theta),cos(record.truth.theta)),y(:,10)]);ylabel('electrical rad');legend('true','estimate');grid on
nexttile;plot(t,y(:,24));ylabel('angle error rad');grid on
nexttile;plot(t,[record.truth.omega,y(:,11),y(:,22)]);ylabel('electrical rad/s');legend('true','PLL','filtered');grid on
nexttile;plot(t,[y(:,13:14),y(:,17)]);ylabel('rotor flux Wb');legend('alpha','beta','magnitude');grid on
nexttile;plot(t,[y(:,12),y(:,21),y(:,23)]);ylabel('valid / A-eq / ready');legend('valid','flux residual','comp ready');xlabel('time s');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.svg']),ContentType='vector');
end
