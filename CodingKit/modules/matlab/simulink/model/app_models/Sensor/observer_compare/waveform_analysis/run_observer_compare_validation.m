function report=run_observer_compare_validation(selectedCases)
%RUN_OBSERVER_COMPARE_VALIDATION Check physical observer inputs and shadow behavior.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SensorObserverCompare';open_system(fullfile(module,'src',[model,'.slx']));
names={'positive','negative','no_feedback_delay','two_feedback_ticks', ...
    'rs_plus_20_percent','disabled_observer','reset_observer','imposed_rotation'};
if nargin>0
    selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));
    names=names(ismember(names,selectedCases));assert(~isempty(names));
end
records=struct();metrics=cell(1,numel(names));
for test=1:numel(names)
    name=names{test};p=observer_compare_parameters();
    switch name
        case 'negative'
            p.experimentCfg.SpeedReference=-40;p.experimentCfg.LoadTorque=-0.1;p.compareCfg.Direction=-1;
        case 'no_feedback_delay',p.timingCfg.FeedbackTicks=0;
        case 'two_feedback_ticks',p.timingCfg.FeedbackTicks=2;
        case 'rs_plus_20_percent',p.smoCfg.Rs=1.2*p.pmsmCfg.Rs;
        case 'disabled_observer',p.compareCfg.ObserverEnable=0;
        case 'reset_observer',p.compareCfg.ObserverReset=1;
        case 'imposed_rotation'
            p.experimentCfg.UseMechanical=0;p.experimentCfg.ImposedElectricalSpeed=200;
            p.experimentCfg.Mode=0;p.experimentCfg.Duration=0.4;
    end
    assert(p.pmsmCfg.Ld==p.pmsmCfg.Lq,'The basic SMO fixture is SPMSM only.');
    p.smoCfg=refresh_smo_parameters(p.smoCfg);
    assert(p.smoCfg.Ts==p.pllCfg.Ts && p.smoCfg.Ts==p.currentCfg.Ts && p.timingCfg.Ts==p.currentCfg.Ts);
    input=Simulink.SimulationInput(model);fields=fieldnames(p);
    for index=1:numel(fields),input=input.setVariable(fields{index},p.(fields{index}),'Workspace',model);end
    timer=tic;result=sim(input);wallTime=toc(timer);
    trace=result.observer_trace.signals.values;time=result.observer_trace.time;
    sensorTrace=result.trace.signals.values;sensorTime=result.trace.time;
    assert(size(trace,2)==28 && size(sensorTrace,2)==52);
    assert(all(isfinite(trace),'all') && all(isfinite(sensorTrace),'all'));
    assert(isequal(time,sensorTime));
    assert(abs(time(end)-p.experimentCfg.Duration)<p.currentCfg.Ts/4);
    assert(max(abs(trace(:,24)-wrap(trace(:,5)-trace(:,1))))<1e-12);
    assert(max(abs(trace(:,25)-(trace(:,6)-trace(:,2))))<1e-12);
    assert(max(abs(trace(:,26:27)-(trace(:,10:11)-trace(:,17:18))),[],'all')<1e-12);
    assert(max(abs(trace(:,28)-vecnorm(trace(:,26:27),2,2)))<1e-12);
    age=p.timingCfg.FeedbackTicks*p.experimentCfg.UseTiming;
    sample=(1+age:numel(time))';older=sample-age;
    phaseVoltage=sensorTrace(:,43:45);phaseCurrent=sensorTrace(:,40:42);
    voltageAB=[(2*phaseVoltage(:,1)-phaseVoltage(:,2)-phaseVoltage(:,3))/3, ...
        (phaseVoltage(:,2)-phaseVoltage(:,3))/sqrt(3)];
    currentAB=[(2*phaseCurrent(:,1)-phaseCurrent(:,2)-phaseCurrent(:,3))/3, ...
        (phaseCurrent(:,2)-phaseCurrent(:,3))/sqrt(3)];
    angleAgeError=max(abs(wrap(trace(sample,1)-trace(older,3))));
    speedAgeError=max(abs(trace(sample,2)-trace(older,4)));
    voltageAgeError=max(abs(trace(sample,19:20)-voltageAB(older,:)),[],'all');
    currentAgeError=max(abs(trace(sample,17:18)-currentAB(older,:)),[],'all');
    assert(angleAgeError<1e-9 && speedAgeError<1e-9 && voltageAgeError<1e-10 && currentAgeError<1e-10, ...
        'Observer current/voltage/reference ages must agree with the physical trace.');
    tail=time>=p.experimentCfg.Duration-0.2;
    metric=struct('name',name,'passed',true,'window_s',[time(find(tail,1)),time(end)], ...
        'angle_RMS_rad',sqrt(mean(trace(tail,24).^2)), ...
        'speed_RMS_electrical_rad_s',sqrt(mean(trace(tail,25).^2)), ...
        'valid_fraction',mean(trace(tail,7)>0.5),'residual_RMS_A',sqrt(mean(trace(tail,28).^2)), ...
        'first_valid_s',NaN,'angle_age_error_rad',angleAgeError,'speed_age_error_rad_s',speedAgeError, ...
        'voltage_age_error_V',voltageAgeError,'current_age_error_A',currentAgeError, ...
        'feedback_ticks',age,'wall_time_s',wallTime,'control_trace_difference',NaN);
    firstValid=find(trace(:,7)>0.5,1);if ~isempty(firstValid),metric.first_valid_s=time(firstValid);end
    if ismember(name,{'disabled_observer','reset_observer'})
        assert(all(trace(:,5:16)==0,'all') && metric.valid_fraction==0);
    else
        assert(metric.angle_RMS_rad<0.1 && metric.speed_RMS_electrical_rad_s<8 && metric.valid_fraction>0.95);
    end
    if isfield(records,'positive') && ismember(name,{'rs_plus_20_percent','disabled_observer','reset_observer'})
        metric.control_trace_difference=max(abs(sensorTrace-records.positive.sensor_trace),[],'all');
        assert(metric.control_trace_difference<1e-10,'The observer must not influence Sensor control.');
    end
    records.(name)=struct('time',time,'trace',trace,'sensor_trace',sensorTrace,'parameters',p,'metric',metric);
    metrics{test}=metric;
    fprintf('%s: PASS, angle RMS %.6g rad, speed RMS %.6g rad/s, valid %.4f\n', ...
        name,metric.angle_RMS_rad,metric.speed_RMS_electrical_rad_s,metric.valid_fraction);
end
metrics=[metrics{:}];report=struct('release',version('-release'),'passed',all([metrics.passed]), ...
    'case_count',numel(names),'cases',metrics,'control_feedback','position_sensor', ...
    'observer_in_control_loop',false,'physical_PMSM_MIL',true,'hardware_tested',false);
save(fullfile(module,'waveform_analysis','results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','metrics.json'),'w');
cleanup=onCleanup(@()fclose(file));fwrite(file,jsonencode(report,PrettyPrint=true));clear cleanup
for name={'positive','negative','two_feedback_ticks'}
    if isfield(records,name{1}),plotCase(records.(name{1}),name{1},module);end
end
disp(report);
end
function result=wrap(value)
result=atan2(sin(value),cos(value));
end
function plotCase(record,name,module)
figureHandle=figure('Visible','off','Position',[100,100,1100,1000]);
cleanup=onCleanup(@()close(figureHandle));tiledlayout(5,1);time=record.time;x=record.trace;
nexttile;plot(time,x(:,[2,6]));ylabel('electrical rad/s');legend('sensor','SMO');grid on
nexttile;plot(time,x(:,24));ylabel('angle error (rad)');grid on
nexttile;plot(time,x(:,[17,10,18,11]));ylabel('current (A)');legend('i alpha','hat alpha','i beta','hat beta');grid on
nexttile;plot(time,x(:,19:20));ylabel('applied V');legend('aligned u alpha','aligned u beta');grid on
nexttile;plot(time,x(:,7));ylabel('valid');xlabel('time (s)');ylim([-0.1,1.1]);grid on
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.png']));
exportgraphics(figureHandle,fullfile(module,'waveform_analysis',[name,'.svg']),ContentType='vector');
end
