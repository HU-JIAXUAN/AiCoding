function report=run_open_loop_drive_validation(folder)
%RUN_OPEN_LOOP_DRIVE_VALIDATION Branch, timing and phase checks with independent input.
module=fileparts(fileparts(mfilename('fullpath')));if nargin==0,folder=fileparts(mfilename('fullpath'));end
if ~isfolder(folder),mkdir(folder);end
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));model='OpenLoopDriveTest';load_system(model);
cleanup=onCleanup(@()close_system(model,0));names={'if_positive','if_negative','vf_positive','vf_negative','frequency_limit', ...
    'voltage_limit','moving_refused','overcurrent','reset_clear','disable_clear','nonfinite_frequency','invalid_bus','zero_frequency'};
results=cell(numel(names),1);fixture=open_loop_drive_test_parameters();
for number=1:numel(names)
    name=names{number};cfg=open_loop_drive_parameters();cfg.Ts=fixture.ValidationTs;cfg.ObserveTime=fixture.ObserveTime;cfg.ObserveTimeout=fixture.ObserveTimeout;cfg.AlignTime=fixture.AlignTime;cfg.AlignRampTime=fixture.AlignRampTime;
    frequency=fixture.Frequency;
    if startsWith(name,'vf')||strcmp(name,'voltage_limit'),cfg.Kind=2;cfg.AlignAmplitude=fixture.AlignVoltage;end
    if contains(name,'negative'),frequency=-frequency;end
    if strcmp(name,'frequency_limit'),frequency=fixture.LimitFrequency;cfg.FrequencySlew=fixture.LimitSlew;end
    if strcmp(name,'zero_frequency'),frequency=0;end
    if strcmp(name,'voltage_limit'),cfg.VfSlope=fixture.VfSlope;end
    cfg=refresh_open_loop_drive_parameters(cfg);time=(0:cfg.Ts:fixture.Duration)';
    values=[frequency+0*time,ones(size(time)),zeros(size(time)),zeros(size(time)),zeros(size(time)),fixture.BusVoltage+0*time];
    switch name
        case 'voltage_limit',values(:,6)=fixture.LimitedBus;
        case 'moving_refused',values(:,5)=fixture.MovingTerminal;
        case 'overcurrent',values(time>=fixture.FaultTime,4)=cfg.CurrentTrip+1;
        case 'reset_clear',values(time>=fixture.FaultTime&time<fixture.ClearEndTime,3)=1;
        case 'disable_clear',values(time>=fixture.FaultTime&time<fixture.ClearEndTime,2)=0;
        case 'nonfinite_frequency',values(time>=fixture.FaultTime,1)=NaN;
        case 'invalid_bus',values(time>=fixture.FaultTime,6)=0;
    end
    stimulus=struct('time',[],'signals',struct('values',values,'dimensions',6));
    in=Simulink.SimulationInput(model);in=in.setVariable('openLoopCfg',cfg,'Workspace',model);
    in=in.setVariable('openLoopTestCfg',fixture,'Workspace',model);in=in.setVariable('testStim',stimulus,'Workspace',model);out=sim(in);
    raw=out.trace.signals.values;if size(raw,1)==numel(time),trace=raw;else,trace=reshape(raw,14,[])';end
    y=trace(:,7:14);assert(all(isfinite(y),'all'));run=y(:,5)==3;pair=run(1:end-1)&run(2:end)&values(1:end-1,2)==1&values(2:end,2)==1&values(1:end-1,3)==0&values(2:end,3)==0;
    a=atan2(sin(diff(y(:,1))),cos(diff(y(:,1))));b=2*pi*cfg.Ts*y(1:end-1,2);
    if any(pair),assert(max(abs(a(pair)-b(pair)),[],'all')<fixture.PhaseTolerance);end
    assert(all(abs(y(:,2))<=cfg.MaximumFrequency+eps(cfg.MaximumFrequency)));
    off=values(:,2)==0|values(:,3)==1;assert(all(y(off,3:6)==0,'all'));
    switch name
        case 'moving_refused',assert(all(y(:,4)==0)&&y(end,6)==3);
        case 'overcurrent',assert(y(end,6)==1&&all(y(time>=fixture.FaultTime+cfg.Ts,4)==0));
        case {'nonfinite_frequency','invalid_bus'},assert(y(end,6)==2);
        otherwise,assert(all(y(:,6)==0)&&any(run));
    end
    if strcmp(name,'voltage_limit'),assert(y(end,8)==1&&y(end,3)<=fixture.LimitedBus*cfg.VoltageFraction+1e-9);end
    if strcmp(name,'zero_frequency'),assert(all(y(:,2)==0));end
    results{number}=struct('name',name,'passed',true,'final_stage',y(end,5),'final_fault',y(end,6),'final_frequency',y(end,2));
    fprintf('OPEN_LOOP_REFERENCE %s passed\n',name);
end
report=struct('status','passed','release',version('-release'),'model',model,'cases',numel(results),'results',{results},'raw_MAT_written',false);
fid=fopen(fullfile(folder,'open_loop_metrics.json'),'w','n','UTF-8');fwrite(fid,jsonencode(report,PrettyPrint=true),'char');fclose(fid);
end
