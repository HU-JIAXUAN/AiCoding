function report=run_startup_validation()
%RUN_STARTUP_VALIDATION Check sequence times, references and latched failures.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'));
model='SensorlessStartupTest';open_system(fullfile(module,'src',[model,'.slx']));
names={'positive_timeout','negative_timeout','acquired','flying_acquire', ...
    'reset','disable','invalid_direction','disabled','fault_latched','parameter_override'};
records=struct();metrics=struct([]);
for test=1:numel(names)
    name=names{test};cfg=startup_parameters();
    if strcmp(name,'parameter_override')
        cfg.Ts=100e-6;cfg.FinalOmega=300;cfg.StartupCurrent=3.5;
        cfg=refresh_startup_parameters(cfg);
    end
    sample=(0:round(1.1/cfg.Ts))';time=sample*cfg.Ts;
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    enable=ones(size(time));reset=zeros(size(time));
    direction=ones(size(time));acquired=zeros(size(time));
    switch name
        case 'negative_timeout',direction(:)=-1;
        case 'acquired',acquired(event(0.58))=1;
        case 'flying_acquire',acquired(event(0.015))=1;
        case 'reset'
            acquired(event(0.58) & ~event(0.64))=1;
            reset(event(0.65) & ~event(0.6501))=1;
        case 'disable',enable(event(0.4) & ~event(0.45))=0;
        case 'invalid_direction',direction(event(0.2) & ~event(0.25))=0;
        case 'disabled',enable(:)=0;
        case 'fault_latched'
            direction(event(1.01))=0;acquired(event(1.02))=1;
    end
    stimulus.time=time;stimulus.signals.values=[enable,reset,direction,acquired];
    stimulus.signals.dimensions=4;
    input=Simulink.SimulationInput(model);
    input=input.setVariable('startupCfg',cfg,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    input=input.setModelParameter('StopTime',num2str(time(end),16));
    result=sim(input);trace=result.trace.signals.values;actualTime=result.trace.time;
    assert(size(trace,2)==12 && all(isfinite(trace),'all'));
    assert(isequal(trace(:,1:4),stimulus.signals.values),'Recorded input samples differ from the requested fixture.');
    assert(max(abs(trace(:,5)))<=pi+1e-12);
    assert(max(abs(trace(:,6)))<=cfg.FinalOmega+1e-10);
    assert(min(trace(:,7))>=0 && max(trace(:,7))<=cfg.StartupCurrent+1e-12);
    assert(all(trace(:,8)==0));
    stopped=trace(:,1)<0.5 | trace(:,2)>0.5;
    assert(all(trace(stopped,5)==cfg.Theta0) && all(trace(stopped,6:12)==0,'all'));
    ready=trace(:,9)>0.5;
    assert(all(ismember(trace(ready,10),[4,5])) && all(abs(trace(ready,6))>=cfg.MinCaptureOmega));
    faultIndex=find(trace(:,11)>0,1);faultTime=NaN;
    if ~isempty(faultIndex),faultTime=actualTime(faultIndex);end
    if ismember(name,{'positive_timeout','negative_timeout','parameter_override','fault_latched'})
        rampIndex=find(trace(:,10)==4,1);assert(~isempty(rampIndex));
        expectedRamp=cfg.Ts*(1+sum(cfg.Samples([1,2,4])));
        assert(abs(actualTime(rampIndex)-expectedRamp)<cfg.Ts/4);
        assert(abs(faultTime-(expectedRamp+cfg.Samples(8)*cfg.Ts))<cfg.Ts/4);
        assert(all(trace(faultIndex:end,10)==7) && all(trace(faultIndex:end,11)==1));
        ramp=trace(:,10)==4;
        sample=round((actualTime(ramp)-expectedRamp)/cfg.Ts);
        signValue=direction(1);
        expectedTheta=signValue*cfg.FinalOmega/cfg.Samples(6)*cfg.Ts.*sample.*(sample-1)/2;
        difference=trace(ramp,5)-expectedTheta;
        assert(max(abs(atan2(sin(difference),cos(difference))))<1e-10);
    elseif ismember(name,{'acquired','flying_acquire'})
        active=acquired>0.5;assert(all(trace(active,10)==6) && all(trace(active,11)==0));
        assert(all(trace(active,7:9)==0,'all'));
        if strcmp(name,'flying_acquire'),assert(all(trace(:,7:8)==0,'all'));end
    elseif strcmp(name,'invalid_direction')
        failed=actualTime>=0.2;assert(all(trace(failed,10)==7) && all(trace(failed,11)==2));
        assert(all(trace(failed,7:9)==0,'all'));
        assert(all(trace(failed,12)==0));
    elseif strcmp(name,'reset')
        after=actualTime>0.6501;assert(any(trace(after,10)==2) && any(trace(after,10)==4));
        assert(all(trace(:,11)==0));
    elseif strcmp(name,'disable')
        after=actualTime>=0.45;assert(any(trace(after,10)==2) && any(trace(after,10)==4));
        assert(all(trace(:,11)==0));
    end
    metric=struct('name',name,'maximum_current_reference_A',max(hypot(trace(:,7),trace(:,8))), ...
        'maximum_abs_omega_command_rad_s',max(abs(trace(:,6))), ...
        'fault_time_s',faultTime,'final_mode',trace(end,10),'final_fault',trace(end,11),'passed',true);
    if test==1,metrics=metric;else,metrics(test)=metric;end
    records.(name)=struct('configuration',cfg,'inputs',stimulus.signals.values, ...
        'time',actualTime,'trace',trace,'metrics',metric);
end
channels={'enable','reset','direction','acquired','theta_start','omega_start', ...
    'id_start','iq_start','ready','mode','fault','elapsed'};
report=struct('status','passed','release',version('-release'),'tests',numel(names), ...
    'passed',sum([metrics.passed]),'channels',{channels},'metrics',metrics);
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'results.mat'),'records','report');
file=fopen(fullfile(folder,'metrics.json'),'w');fprintf(file,'%s',jsonencode(report,PrettyPrint=true));fclose(file);
plotCase(records.positive_timeout,folder,'timeout');plotCase(records.acquired,folder,'acquired');
plotCase(records.invalid_direction,folder,'fault');disp(struct2table(metrics));
end
function plotCase(record,folder,name)
handle=figure('Visible','off','Position',[100,100,1100,850]);t=record.time;y=record.trace;
tiledlayout(4,1);nexttile;plot(t,y(:,5));ylabel('field angle / rad');grid on;
nexttile;plot(t,y(:,6));ylabel('field speed / rad/s');grid on;
nexttile;plot(t,y(:,7:8));ylabel('reference / A');legend('virtual d','virtual q');grid on;
nexttile;stairs(t,y(:,9:11));ylabel('ready / mode / fault');legend('ready','mode','fault');xlabel('time / s');grid on;
exportgraphics(handle,fullfile(folder,[name,'.png']));
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');close(handle);
end
