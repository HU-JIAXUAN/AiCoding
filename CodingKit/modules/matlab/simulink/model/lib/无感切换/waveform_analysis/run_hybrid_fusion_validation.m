function report=run_hybrid_fusion_validation(selectedCases)
%RUN_HYBRID_FUSION_VALIDATION Verify temporal qualification, fusion and failure exits.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'));
model='HybridFusionTest';load_system(fullfile(module,'src',[model,'.slx']));
cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'round_trip','negative_round_trip','wrap_boundary','low_only','high_only_start', ...
    'high_start_disabled','no_sources','phase_disagreement','speed_disagreement', ...
    'qualification_restart','high_dropout_short','high_dropout_long','low_dropout_short', ...
    'low_dropout_long','phase_jump_high','high_nan_short','unused_low_nan', ...
    'disable_restart','reset','reset_latched_fault','unanchored_return','same_branch_return', ...
    'injection_hysteresis','coarse_period','unsupported_low_speed','invalid_command', ...
    'low_loss_high_fallback','high_loss_low_fallback','direction_reverse','negative_high_start'};
if nargin>0,selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));names=names(ismember(names,selectedCases));end
assert(~isempty(names));records=struct();metrics=struct([]);
for number=1:numel(names)
    name=names{number};cfg=hybrid_fusion_parameters();test=hybrid_fusion_test_parameters();
    if ismember(name,{'low_only','low_dropout_short','low_dropout_long','reset_latched_fault','invalid_command'})
        test.PeakOmega=20;test.ReturnPi=0;test.Duration=.4;
    elseif ismember(name,{'phase_disagreement','speed_disagreement','qualification_restart','low_loss_high_fallback','high_loss_low_fallback'})
        test.InitialOmega=50;test.PeakOmega=50;test.ReturnPi=0;test.Duration=.4;
    elseif ismember(name,{'high_only_start','high_start_disabled','negative_high_start'})
        test.InitialOmega=100;test.PeakOmega=100;test.Duration=.4;test.ReturnPi=0;
    end
    switch name
        case 'negative_round_trip',test.InitialOmega=-20;test.PeakOmega=-100;
        case 'negative_high_start',test.InitialOmega=-100;test.PeakOmega=-100;
        case 'wrap_boundary',test.InitialAngle=pi-.005;
        case 'high_start_disabled',cfg.AllowHighStart=0;
        case 'unused_low_nan',test.Duration=.7;
        case 'same_branch_return',test.ReturnPi=0;
        case 'coarse_period',cfg.Ts=.001;
        case 'direction_reverse',test.PeakOmega=-100;test.ReturnTime=.72;
        case 'unsupported_low_speed',test.InitialOmega=90;test.PeakOmega=90;test.ReturnPi=0;test.Duration=.4;
        case 'injection_hysteresis',test.InitialOmega=77;test.PeakOmega=77;test.ReturnPi=0;test.Duration=.6;
    end
    cfg=refresh_hybrid_fusion_parameters(cfg);stimulus=hybrid_fusion_stimulus(test,cfg);
    t=stimulus.time;u=stimulus.signals.values;
    event=@(start,stop)t>=start-cfg.Ts/10 & t<stop-cfg.Ts/10;
    switch name
        case 'no_sources',u(:,[3,6])=0;
        case 'phase_disagreement',u(:,4)=wrap(u(:,9)+1.2);
        case 'speed_disagreement',u(:,5)=u(:,5)+50;
        case 'qualification_restart',u(t<.02,6)=0;u(event(.025,.027),6)=0;
        case 'high_dropout_short',u(event(.6,.6005),6)=0;
        case 'high_dropout_long',u(event(.6,.65),6)=0;
        case 'low_dropout_short',u(event(.2,.2005),3)=0;
        case {'low_dropout_long','reset_latched_fault'},u(event(.2,.205),3)=0;
        case 'phase_jump_high',u(t>=.6,4)=wrap(u(t>=.6,4)+.5);
        case 'high_nan_short',u(event(.6,.6005),4)=NaN;
        case 'unused_low_nan',u(t>=.5,1)=NaN;
        case 'disable_restart',u(event(.6,.65),7)=0;
        case 'reset',u(event(.6,.6+cfg.Ts),8)=1;
        case 'invalid_command',u(t>=.2,7)=NaN;
        case 'low_loss_high_fallback',u(t>=.2,3)=0;
        case 'high_loss_low_fallback',u(t>=.2,6)=0;
        case 'unsupported_low_speed',u(:,3)=1;u(:,6)=0;
        case 'unanchored_return'
            u(t>=.8,6)=0;u(t>=.8,3)=1;u(t>=.8,2)=20;
            u(t>=.8,1)=wrap(u(t>=.8,9)+pi);
        case 'injection_hysteresis'
            omega=77*ones(size(t));middle=event(.2,.4);
            omega(middle)=72+2*sin(2*pi*20*(t(middle)-.2));omega(t>=.4)=64;
            theta=test.InitialAngle+cumtrapz(t,omega);
            u(:,[1,4,9])=[wrap(theta+test.LowPhaseBias),wrap(theta+test.HighPhaseBias),wrap(theta)];
            u(:,[2,5,10])=[omega,omega,omega];u(:,[3,6])=1;
    end
    if strcmp(name,'reset_latched_fault'),u(event(.25,.25+cfg.Ts),8)=1;end
    stimulus.signals.values=u;
    in=Simulink.SimulationInput(model);
    in=in.setVariable('fusionCfg',cfg,'Workspace',model);
    in=in.setVariable('fusionTestCfg',test,'Workspace',model);
    in=in.setVariable('testStim',stimulus,'Workspace',model);
    out=sim(in);trace=out.trace.signals.values;y=trace(:,11:27);
    assert(size(trace,2)==27 && isequaln(trace(:,1:10),u));
    assert(all(isfinite(y),'all') && max(abs(y(:,1)))<=pi+1e-12);
    assert(all(y(:,[5,6])>=0 & y(:,[5,6])<=1,'all'));
    off=u(:,7)<.5 | u(:,8)>.5;
    assert(all(y(off,:)==0,'all'));
    badCommand=~isfinite(u(:,7)) | ~isfinite(u(:,8));
    assert(all(y(badCommand,8)==2) && all(y(badCommand,6)==0));
    fault=y(:,8)>0;assert(all(y(fault,4)==0 & y(fault,7)==4));
    assert(max(abs(y(:,16)))<=cfg.PhaseCorrectionRate*cfg.Ts+1e-12);
    consecutive=y(1:end-1,4)>.5 & y(2:end,4)>.5;
    frameRate=wrap(diff(y(:,1)))/cfg.Ts;
    assert(max([0;abs(frameRate(consecutive)-y(find(consecutive)+1,3))])<1e-7);
    assert(max([0;abs(y(consecutiveIndices(consecutive),3)-y(consecutiveIndices(consecutive),2)-y(consecutiveIndices(consecutive),16)/cfg.Ts)])<1e-7);
    stable=~off(1:end-1) & ~off(2:end) & ~fault(1:end-1) & ~fault(2:end) & ~badCommand(1:end-1) & ~badCommand(2:end);
    injectionStep=abs(diff(y(:,6)));
    assert(max([0;injectionStep(stable)])<=cfg.Ts/cfg.InjectionRampTime+1e-12);
    thetaError=wrap(y(:,1)-u(:,9));first=find(y(:,4)>.5,1);firstTime=NaN;
    if ~isempty(first),firstTime=t(first);end
    rejected=ismember(name,{'no_sources','high_start_disabled','unsupported_low_speed'});
    expectedFault=ismember(name,{'high_dropout_long','low_dropout_long','phase_jump_high','invalid_command','unanchored_return'});
    if rejected
        assert(isempty(first) && all(y(:,7)==0) && ~any(fault));
    elseif expectedFault
        assert(~isempty(first) && any(fault) && y(end,8)>0 && y(end,4)==0 && y(end,6)==0);
    elseif strcmp(name,'reset_latched_fault')
        assert(any(fault) && ~any(fault(t>=.25)) && y(end,4)==1);
    else
        assert(~isempty(first) && ~any(fault) && y(end,4)==1,name);
        if ~ismember(name,{'disable_restart','reset'})
            assert(all(y(first:end,4)==1),name);
        end
        assert(max(abs(thetaError(y(:,4)>.5)))<.15,name);
    end
    if ismember(name,{'round_trip','negative_round_trip','wrap_boundary','coarse_period','direction_reverse','same_branch_return'})
        assert(any(y(:,5)==1) && y(end,5)==0 && min(y(t>.5 & t<.7,6))<.01);
        assert(y(end,6)>.99 && y(end,17)==1);
        if ~strcmp(name,'same_branch_return'),assert(y(end,11)==1);else,assert(y(end,11)==0);end
        normal=y(1:end-1,9)>.5 & y(1:end-1,10)>.5 & y(2:end,9)>.5 & y(2:end,10)>.5;
        weightStep=abs(diff(y(:,5)));
        assert(max([0;weightStep(normal)])<=cfg.Ts/cfg.BlendTime+1e-12);
    elseif ismember(name,{'phase_disagreement','speed_disagreement','low_only'})
        assert(all(y(:,5)==0));
    elseif ismember(name,{'high_only_start','negative_high_start'})
        assert(y(end,5)==1 && y(end,6)==0);
    elseif strcmp(name,'qualification_restart')
        ready=find(y(:,10)>.5,1);
        assert(abs(t(ready)-(.027+(cfg.QualificationSamples-1)*cfg.Ts))<cfg.Ts/4);
    elseif ismember(name,{'high_dropout_long','phase_jump_high'})
        failed=find(fault,1);assert(abs(t(failed)-(.6+(cfg.LossSamples-1)*cfg.Ts))<cfg.Ts/4);
    elseif strcmp(name,'low_dropout_long')
        failed=find(fault,1);assert(abs(t(failed)-(.2+(cfg.LossSamples-1)*cfg.Ts))<cfg.Ts/4);
    elseif strcmp(name,'unanchored_return')
        assert(~any(y(t>=.8,9)) && y(end,17)==0);
    elseif strcmp(name,'injection_hysteresis')
        assert(max(y(event(.25,.35),6))<.01 && min(y(t>.5,6))>.99);
    elseif strcmp(name,'low_loss_high_fallback'),assert(y(end,5)==1);
    elseif strcmp(name,'high_loss_low_fallback'),assert(y(end,5)==0);
    end
    active=y(:,4)>.5;errorRms=NaN;
    if any(active),errorRms=sqrt(mean(thetaError(active).^2));end
    metric=struct('name',name,'first_valid_s',firstTime,'angle_rms_rad',errorRms, ...
        'final_beta',y(end,5),'minimum_injection',min(y(:,6)), ...
        'final_low_pi_flip',y(end,11),'maximum_fault',max(y(:,8)),'status','passed');
    if number==1,metrics=metric;else,metrics(number)=metric;end
    records.(name)=struct('fusionCfg',cfg,'testCfg',test,'stimulus',stimulus,'time',out.trace.time, ...
        'trace',trace,'angle_error',thetaError,'metrics',metrics(number));
    fprintf('%s passed\n',name);
end
report=struct('release',version('-release'),'root',matlabroot,'kind','analytic independent trackers; no physical PMSM', ...
    'tests',numel(names),'passed',numel(names),'metrics',metrics);
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'fusion_results.mat'),'records','report','-v7.3');
file=fopen(fullfile(folder,'fusion_metrics.json'),'w');fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
end
function index=consecutiveIndices(mask)
index=find(mask)+1;
end
function result=wrap(angle)
result=atan2(sin(angle),cos(angle));
end
