function report=run_emf_validation()
%RUN_EMF_VALIDATION Exercise the saved SPMSM and IPMSM observer models.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));pll=fullfile(fileparts(fileparts(module)),'相位跟踪');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'),fullfile(pll,'parameter'));
names={'positive','negative','high_speed','acceleration','current_ramp','resistance_error', ...
    'voltage_bias','measurement_noise','wrong_direction','zero_speed','zero_speed_enabled', ...
    'low_speed_enabled','disable','reset','invalid_direction','reversal'};
records=struct();metrics=struct([]);
for variant={'spmsm','ipmsm'}
    kind=variant{1};if strcmp(kind,'spmsm'),model='LinearEmfTest';else,model='EemfObserverTest';end
    open_system(fullfile(module,'src',[model,'.slx']));
    for test=1:numel(names)
        name=names{test};cfg=emf_parameters(kind);fixture=emf_test_parameters();
        pllCfg=angle_tracking_parameters();pllCfg.Ts=cfg.Ts;pllCfg.MinMagnitude=cfg.MinEmf;
        sample=(0:round(fixture.Duration/cfg.Ts))';time=sample*cfg.Ts;
        one=ones(size(time));omega=fixture.ElectricalSpeed*one;id=fixture.Id*one;iq=fixture.Iq*one;motor=cfg;
        event=@(seconds)sample>=round(seconds/cfg.Ts);
        switch name
            case 'negative',omega=-omega;
            case 'high_speed',omega(:)=600;
            case 'acceleration',omega=150+450*time/fixture.Duration;
            case 'current_ramp'
                ramp=min(max((time-0.1)/0.02,0),1);id=id-2*ramp;iq=iq+2*ramp;
            case 'resistance_error',motor.Rs=1.2*cfg.Rs;
            case {'zero_speed','zero_speed_enabled'},omega(:)=0;
            case 'low_speed_enabled',omega(:)=5;
            case 'reversal',omega(event(0.2))=-200;
        end
        [stimulus,truth]=emf_fixture(time,omega,fixture.InitialAngle,id,iq,motor);
        if ismember(name,{'zero_speed_enabled','low_speed_enabled'}),stimulus.signals.values(:,5)=1;end
        switch name
            case 'voltage_bias',stimulus.signals.values(:,1)=stimulus.signals.values(:,1)+0.03;
            case 'measurement_noise'
                stream=RandStream('mt19937ar','Seed',42);
                stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+0.005*randn(stream,numel(time),2);
            case 'wrong_direction',stimulus.signals.values(:,5)=-stimulus.signals.values(:,5);
            case 'disable',stimulus.signals.values(event(0.2)&~event(0.24),6)=0;
            case 'reset',stimulus.signals.values(sample==round(0.2/cfg.Ts),7)=1;
            case 'invalid_direction',stimulus.signals.values(:,5)=2;
        end
        assert(cfg.Ts*2*pi*cfg.BandwidthHz<0.2 && cfg.Rs>0 && cfg.Ld>0 && cfg.Lq>0);
        input=Simulink.SimulationInput(model);
        input=input.setVariable('emfCfg',cfg,'Workspace',model);
        input=input.setVariable('pllCfg',pllCfg,'Workspace',model);
        input=input.setVariable('testStim',stimulus,'Workspace',model);
        input=input.setModelParameter('StopTime',num2str(time(end),16));
        timer=tic;output=sim(input);elapsed=toc(timer);trace=output.trace.signals.values;
        assert(ismatrix(trace) && size(trace,2)==22 && all(isfinite(trace),'all'));
        assert(isequal(trace(:,1:9),stimulus.signals.values));
        assert(max(abs(output.trace.time-time))<1e-12);
        tail=time>=fixture.Duration-0.1;valid=trace(:,12)>0.5;
        phaseError=atan2(sin(trace(:,10)-truth.theta),cos(trace(:,10)-truth.theta));
        angleRms=sqrt(mean(phaseError(tail).^2));speedRms=sqrt(mean((trace(tail,11)-omega(tail)).^2));
        validFraction=mean(valid(tail));residual=sqrt(sum(trace(:,17:18).^2,2));
        if ismember(name,{'zero_speed','invalid_direction'})
            assert(all(~valid) && all(trace(:,10:21)==0,'all'));
        elseif ismember(name,{'zero_speed_enabled','low_speed_enabled'})
            % Keep the estimator enabled: invalidity must come from the
            % available EMF/speed information, not from direction=0.
            assert(all(~valid(tail)) && max(hypot(trace(tail,13),trace(tail,14)))<cfg.MinEmf/2);
            assert(sqrt(mean(residual(tail).^2))<0.05);
        elseif strcmp(name,'wrong_direction')
            assert(all(~valid(tail)) && abs(angleRms-pi)<0.15 && speedRms<3);
        else
            assert(angleRms<0.12 && speedRms<3 && validFraction>0.95, ...
                '%s/%s angle %.6g speed %.6g valid %.6g',kind,name,angleRms,speedRms,validFraction);
            if strcmp(name,'disable')
                off=event(0.2)&~event(0.24);assert(all(trace(off,10:21)==0,'all'));
            elseif strcmp(name,'reset')
                off=sample==round(0.2/cfg.Ts);assert(all(trace(off,10:21)==0,'all'));
            end
        end
        record=struct('kind',kind,'name',name,'parameters',cfg,'pll',pllCfg,'fixture',fixture, ...
            'time',time,'input',stimulus,'truth',truth,'trace',trace,'wall_time_s',elapsed);
        records.([kind,'_',name])=record;
        metric=struct('kind',kind,'name',name,'angle_RMS_rad',angleRms,'speed_RMS_electrical_rad_s',speedRms, ...
            'valid_fraction',validFraction,'residual_RMS_A',sqrt(mean(residual(tail).^2)),'passed',true);
        if isempty(metrics),metrics=metric;else,metrics(end+1)=metric;end %#ok<AGROW>
        fprintf('EMF %s/%s PASS angle=%.6g speed=%.6g valid=%.4g\n',kind,name,angleRms,speedRms,validFraction);
    end
end
report=struct('release',version('-release'),'status','passed','tests',numel(metrics),'cases',metrics, ...
    'hardware_tested',false,'actual_plant_angle_input_to_observer',false);
save(fullfile(module,'waveform_analysis','results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','metrics.json'),'w');cleanup=onCleanup(@()fclose(file));
fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
for field={'spmsm_positive','ipmsm_positive','ipmsm_current_ramp','ipmsm_reversal'}
    exportCase(records.(field{1}),field{1},module);
end
disp(rmfield(report,'cases'));
end
function exportCase(record,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,900]);cleanup=onCleanup(@()close(figureHandle));
tiledlayout(4,1);t=record.time;y=record.trace;
nexttile;plot(t,[atan2(sin(record.truth.theta),cos(record.truth.theta)),y(:,10)]);ylabel('electrical rad');legend('true wrapped','estimate wrapped');grid on
nexttile;plot(t,atan2(sin(y(:,10)-record.truth.theta),cos(y(:,10)-record.truth.theta)));ylabel('angle error rad');grid on
nexttile;plot(t,[record.truth.omega,y(:,11)]);ylabel('electrical rad/s');legend('true','estimate');grid on
nexttile;plot(t,[y(:,12),hypot(y(:,17),y(:,18))]);ylabel('valid / residual A');legend('valid','residual');xlabel('time s');grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.svg']),ContentType='vector');
end
