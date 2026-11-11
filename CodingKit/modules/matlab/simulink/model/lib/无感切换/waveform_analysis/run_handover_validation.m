function report=run_handover_validation(selectedCases)
%RUN_HANDOVER_VALIDATION Exercise capture qualification, smooth blending and exit.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SensorlessHandoverTest';open_system(fullfile(module,'src',[model,'.slx']));
names={'positive','negative','wrap','flying','flying_disabled','phase_gap', ...
    'speed_gap','residual_block','low_speed','qualification_reset','short_dropout', ...
    'long_dropout','phase_jump','blend_dropout','reset','disable','startup_fault', ...
    'disabled','phase_noise'};
if nargin>0
    selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));
    names=names(ismember(names,selectedCases));assert(~isempty(names));
end
records=struct();metrics=struct([]);
for test=1:numel(names)
    name=names{test};cfg=handover_parameters();sample=(0:round(0.35/cfg.Ts))';time=sample*cfg.Ts;
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    thetaHat=200*time;thetaStart=thetaHat+0.4;
    omegaHat=200*ones(size(time));omegaStart=omegaHat;
    ready=ones(size(time));startupMode=4*ones(size(time));startupFault=zeros(size(time));
    valid=double(event(0.02));residual=0.1*ones(size(time));
    enable=ones(size(time));reset=zeros(size(time));
    switch name
        case 'negative'
            thetaHat=-200*time;thetaStart=thetaHat+0.4;omegaHat(:)=-200;omegaStart(:)=-200;
        case 'wrap',thetaHat=-3.10+200*time;thetaStart=3.12+200*time;
        case {'flying','flying_disabled'}
            thetaStart(:)=0;omegaStart(:)=0;ready(:)=0;startupMode(:)=1;
            thetaHat=2+200*time;valid=double(event(0.005));
            if strcmp(name,'flying_disabled'),cfg.AllowFlying=0;cfg=refresh_handover_parameters(cfg);end
        case 'phase_gap',thetaStart=thetaHat+1.2;
        case 'speed_gap',omegaHat(:)=400;thetaHat=400*time;
        case 'residual_block',residual(:)=2;
        case 'low_speed'
            omegaHat(:)=50;omegaStart(:)=50;thetaHat=50*time;thetaStart=thetaHat+0.4;
        case 'qualification_reset',valid(event(0.025) & ~event(0.027))=0;
        case 'short_dropout',valid(event(0.2) & ~event(0.2005))=0;
        case 'long_dropout',valid(event(0.2) & ~event(0.25))=0;
        case 'phase_jump',thetaHat(event(0.2))=thetaHat(event(0.2))+1.5;
        case 'blend_dropout',valid(event(0.07) & ~event(0.0705))=0;
        case 'reset',reset(event(0.2) & ~event(0.2001))=1;
        case 'disable',enable(event(0.2) & ~event(0.23))=0;
        case 'startup_fault'
            valid(:)=0;startupFault(event(0.15) & ~event(0.2))=1;
        case 'disabled',enable(:)=0;
        case 'phase_noise'
            thetaHat=thetaHat+0.01*sin(400*time);omegaHat=omegaHat+4*cos(400*time);
    end
    u=[wrap(thetaStart),omegaStart,ready,startupMode,startupFault,wrap(thetaHat), ...
        omegaHat,valid,residual,enable,reset];
    stimulus.time=time;stimulus.signals.values=u;stimulus.signals.dimensions=11;
    input=Simulink.SimulationInput(model);
    input=input.setVariable('handoverCfg',cfg,'Workspace',model);
    input=input.setVariable('testStim',stimulus,'Workspace',model);
    result=sim(input);trace=result.trace.signals.values;actualTime=result.trace.time;
    assert(size(trace,2)==22 && all(isfinite(trace),'all'));
    assert(isequal(trace(:,1:11),u),'Recorded input samples differ from the requested fixture.');
    assert(max(abs(trace(:,12)))<=pi+1e-12);
    assert(all(trace(:,15)>=0 & trace(:,15)<=1));
    off=u(:,10)<0.5 | u(:,11)>0.5;
    assert(all(trace(off,13:22)==0,'all') && all(trace(off,12)==u(off,1)));
    acquired=trace(:,18)>0.5;assert(all(trace(acquired,16)==4) && all(trace(acquired,15)==1));
    failed=trace(:,17)>0;assert(all(trace(failed,19)==0) && all(trace(failed,18)==0));
    blendIndex=find(trace(:,16)==3,1);autoIndex=find(trace(:,16)==4,1);faultIndex=find(failed,1);
    blendTime=NaN;autoTime=NaN;faultTime=NaN;
    if ~isempty(blendIndex),blendTime=actualTime(blendIndex);end
    if ~isempty(autoIndex),autoTime=actualTime(autoIndex);end
    if ~isempty(faultIndex),faultTime=actualTime(faultIndex);end
    blocked=ismember(name,{'flying_disabled','phase_gap','speed_gap','residual_block','low_speed','startup_fault','disabled'});
    if blocked
        assert(isempty(blendIndex) && isempty(autoIndex) && all(trace(:,15)==0));
    else
        assert(~isempty(blendIndex) && ~isempty(autoIndex));
        assert(abs(wrap(trace(blendIndex,12)-trace(blendIndex,1)))<1e-12);
    end
    if ismember(name,{'positive','negative','wrap','flying','phase_noise'})
        eligibleTime=actualTime(find(valid>0.5,1));
        assert(abs(blendTime-(eligibleTime+cfg.Samples(1)*cfg.Ts))<cfg.Ts/4);
        assert(abs(autoTime-(blendTime+(cfg.Samples(2)+1)*cfg.Ts))<cfg.Ts/4);
        fraction=min(max((actualTime-blendTime)/(cfg.Samples(2)*cfg.Ts),0),1);
        expectedBeta=fraction.^2.*(3-2*fraction);
        assert(max(abs(trace(:,15)-expectedBeta))<1e-12);
        blending=trace(:,16)==3;expected=wrap(trace(blending,6)+(1-trace(blending,15)).*trace(blending,22));
        assert(max(abs(wrap(trace(blending,12)-expected)))<1e-10);
        if ~strcmp(name,'phase_noise')
            frameRate=wrap(diff(trace(:,12)))/cfg.Ts;
            active=trace(1:end-1,19)>0.5 & trace(2:end,19)>0.5;
            assert(max(abs(frameRate(active)-trace(active,14)))<1e-7);
        end
    elseif strcmp(name,'qualification_reset')
        after=find(actualTime>=0.027,1);
        assert(abs(blendTime-(actualTime(after)+cfg.Samples(1)*cfg.Ts))<cfg.Ts/4);
    elseif strcmp(name,'short_dropout')
        assert(isempty(faultIndex) && trace(end,16)==4);
    elseif strcmp(name,'blend_dropout')
        first=find(time>=0.07,1);last=find(time<0.0705,1,'last');
        assert(all(diff(trace(first:last+1,15))==0) && isempty(faultIndex));
        assert(abs(autoTime-(0.02+cfg.CaptureTime+cfg.BlendTime+cfg.Ts+0.0005))<cfg.Ts/4);
    elseif ismember(name,{'long_dropout','phase_jump'})
        assert(abs(faultTime-(0.2+cfg.Samples(3)*cfg.Ts))<cfg.Ts/4, ...
            '%s fault time %.12g s; expected %.12g s.',name,faultTime,0.2+cfg.Samples(3)*cfg.Ts);
        assert(all(trace(faultIndex:end,16)==5) && all(trace(faultIndex:end,17)==2));
        if strcmp(name,'phase_jump')
            coast=actualTime>=0.2 & actualTime<faultTime;
            assert(max(abs(wrap(trace(coast,12)-200*actualTime(coast))))<1e-10);
        end
    elseif ismember(name,{'reset','disable'})
        assert(isempty(faultIndex));after=actualTime>0.345;
        assert(all(trace(after,16)==4),'The controller did not reacquire after reset/disable.');
    elseif strcmp(name,'startup_fault')
        assert(abs(faultTime-0.15)<cfg.Ts/4 && all(trace(faultIndex:end,17)==1));
    end
    step=abs(wrap(diff(trace(:,12))));active=trace(1:end-1,19)>0.5 & trace(2:end,19)>0.5;
    maxStep=0;if any(active),maxStep=max(step(active));assert(maxStep<0.04);end
    metric=struct('name',name,'blend_start_s',blendTime,'auto_start_s',autoTime, ...
        'fault_time_s',faultTime,'maximum_active_angle_step_rad',maxStep, ...
        'final_mode',trace(end,16),'final_fault',trace(end,17),'passed',true);
    if test==1,metrics=metric;else,metrics(test)=metric;end
    records.(name)=struct('configuration',cfg,'inputs',u,'time',actualTime,'trace',trace,'metrics',metric);
end
channels={'theta_start','omega_start','ready','startup_mode','startup_fault', ...
    'theta_hat','omega_hat','observer_valid','residual_norm','enable','reset', ...
    'theta_used','omega_base','omega_frame','beta','mode','fault','acquired','run', ...
    'qualification_count','loss_count','phase_offset'};
report=struct('status','passed','release',version('-release'),'tests',numel(names), ...
    'passed',sum([metrics.passed]),'metrics',metrics,'channels',{channels});
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'results.mat'),'records','report');
file=fopen(fullfile(folder,'metrics.json'),'w');fprintf(file,'%s',jsonencode(report,PrettyPrint=true));fclose(file);
if isfield(records,'positive'),plotCase(records.positive,folder,'capture');end
if isfield(records,'phase_jump'),plotCase(records.phase_jump,folder,'phase_jump');end
if isfield(records,'blend_dropout'),plotCase(records.blend_dropout,folder,'blend_pause');end
disp(struct2table(metrics));
end
function value=wrap(value)
value=atan2(sin(value),cos(value));
end
function plotCase(record,folder,name)
handle=figure('Visible','off','Position',[100,100,1100,850]);t=record.time;y=record.trace;
tiledlayout(4,1);nexttile;plot(t,y(:,[1,6,12]));ylabel('angle / rad');legend('software','observed','used');grid on;
nexttile;plot(t,y(:,[7,13,14]));ylabel('rad/s');legend('observed','base','frame');grid on;
nexttile;plot(t,y(:,15));ylabel('beta');grid on;
nexttile;stairs(t,y(:,[8,16,17,19]));ylabel('valid/mode/fault/run');legend('valid','mode','fault','run');xlabel('time / s');grid on;
exportgraphics(handle,fullfile(folder,[name,'.png']));
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');close(handle);
end
