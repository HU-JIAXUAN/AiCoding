function report=run_speed_profile_validation()
%RUN_SPEED_PROFILE_VALIDATION Check slew, bounds and clearing on real SLX.
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SpeedProfileTest';load_system(fullfile(module,'src',[model,'.slx']));modelCleanup=onCleanup(@()close_system(model,0));
names={'rise','fall','upper_bound','lower_bound','asymmetric_rates','disable_reacquire','reset_priority','period_1ms'};
records=struct();metrics=cell(size(names));
for n=1:numel(names)
    name=names{n};cfg=speed_profile_parameters();fixture=speed_profile_test_parameters();target=5;
    switch name
        case 'fall',target=-5;
        case 'upper_bound',target=100;
        case 'lower_bound',target=-100;
        case 'asymmetric_rates',cfg.RisingRate=60;cfg.FallingRate=20;target=6;fixture.Duration=.8;
        case {'disable_reacquire','reset_priority'},target=8;
        case 'period_1ms',cfg.Ts=.001;
    end
    cfg=refresh_speed_profile_parameters(cfg);fixture.Ts=cfg.Ts;
    time=(0:round(fixture.Duration/cfg.Ts))'*cfg.Ts;values=[repmat(target,numel(time),1),ones(numel(time),1),zeros(numel(time),1)];
    switch name
        case 'asymmetric_rates',values(time>=.3,1)=-6;
        case 'disable_reacquire',values(time>=.25 & time<.32,2)=0;
        case 'reset_priority',values(round(time/cfg.Ts)==round(.25/cfg.Ts),3)=1;
    end
    stimulus.time=time;stimulus.signals.values=values;stimulus.signals.dimensions=3;
    input=Simulink.SimulationInput(model);
    input=input.setVariable('profileCfg',cfg,'Workspace',model).setVariable('profileTestCfg',fixture,'Workspace',model).setVariable('testStim',stimulus,'Workspace',model);
    input=input.setModelParameter('StopTime',num2str(fixture.Duration,16));output=sim(input);trace=output.trace.signals.values;
    assert(isequal(size(trace),[numel(time),5]) && max(abs(output.trace.time-time))<1e-11 && all(isfinite(trace),'all'));
    active=values(:,2)>.5 & values(:,3)<.5;continuous=active(1:end-1) & active(2:end);
    changes=diff(trace(:,4));slopes=changes(continuous)/cfg.Ts;
    assert(all(trace(:,4)>=cfg.Minimum-1e-10) && all(trace(:,4)<=cfg.Maximum+1e-10));
    assert(all(slopes<=cfg.RisingRate+1e-8) && all(slopes>=-cfg.FallingRate-1e-8));
    assert(all(trace(~active,4:5)==0,'all'));
    restarted=find(active & [true;~active(1:end-1)]);
    assert(all(trace(restarted,4)<=cfg.RisingStep+1e-12) && all(trace(restarted,4)>=-cfg.FallingStep-1e-12));
    if ismember(name,{'rise','fall','upper_bound','lower_bound','period_1ms','reset_priority'})
        assert(abs(trace(end,4)-min(max(target,cfg.Minimum),cfg.Maximum))<1e-10);
    elseif strcmp(name,'asymmetric_rates')
        assert(abs(max(slopes)-60)<1e-8 && abs(min(slopes)+20)<1e-8);
    end
    records.(name)=struct('time',time,'trace',trace,'parameters',cfg,'fixture',fixture,'stimulus',stimulus);
    metrics{n}=struct('name',name,'maximum_slope',max(slopes),'minimum_slope',min(slopes),'final_reference',trace(end,4),'status','passed');
end
report=struct('release',version('-release'),'root',matlabroot,'tests',numel(names),'passed',numel(names),'metrics',{metrics});
save(fullfile(module,'waveform_analysis','profile_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','profile_metrics.json'),'w');fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
end
