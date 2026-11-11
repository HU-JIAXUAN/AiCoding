function summary=validate_open_loop_app(kind,folder)
%VALIDATE_OPEN_LOOP_APP Independent physical criteria, exact RAM metrics.
spec=open_loop_app_spec(kind);addpath(fullfile(spec.module,'parameter'),fullfile(spec.module,'build_process'));
if ~isfolder(folder),mkdir(folder);end
limits=feval([kind '_app_validation_parameters']);results=cell(numel(limits.Names),1);
default=[];counter=[];
for number=1:numel(limits.Names)
    name=limits.Names{number};p=feval([kind '_app_parameters']);expected='tracking';
    switch name
        case 'reverse',p.experimentCfg.Frequency=-p.experimentCfg.Frequency;p.experimentCfg.LoadTorque=-p.experimentCfg.LoadTorque;
        case 'initial_angle',p.motorCfg.Position0=limits.InitialElectricalAngle/p.motorCfg.PolePairs;
        case 'reduced_bus',p.powerCfg.Vdc=limits.ReducedBus;
        case 'frequency_limit',p.experimentCfg.Frequency=limits.LimitFrequency;p.experimentCfg.Duration=limits.LimitDuration;
        case 'load_step',p.experimentCfg.LoadTorque=limits.LoadStep;
        case {'moving_forward_refused','moving_reverse_refused'}
            p.motorCfg.Speed0=limits.MovingSpeed;if contains(name,'reverse'),p.motorCfg.Speed0=-p.motorCfg.Speed0;end
            p.experimentCfg.Duration=limits.RefusalDuration;p.experimentCfg.LoadTorque=0;expected='refused';
        case 'current_trip',p.openLoopCfg.CurrentTrip=limits.TripCurrent;expected='current_trip';
        case {'reset_refused','disable_refused'},p.experimentCfg.Duration=limits.EventDuration;p.experimentCfg.LoadTorque=0;expected='event_refused';
        case 'overload',p.experimentCfg.LoadTorque=limits.CounterLoad;p.experimentCfg.LoadTime=limits.CounterLoadTime;expected='counterexample';
        case 'voltage_shortage',p.powerCfg.Vdc=limits.ShortageBus;expected='voltage_counterexample';
    end
    p=refresh_open_loop_app_parameters(p);stimulus=open_loop_app_stimulus(p);time=stimulus.time;
    if strcmp(name,'reset_refused'),stimulus.signals.values(time>=limits.EventTime&time<limits.EventTime+limits.ResetDuration,3)=1;end
    if strcmp(name,'disable_refused'),stimulus.signals.values(time>=limits.EventTime&time<limits.EventTime+limits.DisableDuration,2)=0;end
    try
        record=run_open_loop_app_case(kind,p,stimulus);metric=score(record,limits,expected);
        metric.name=name;metric.expected=expected;metric.parameters=p;metric.passed=true;
        if strcmp(name,'default'),default=record;export(record,kind,folder,'default',limits);end
        if strcmp(name,'overload'),counter=record;export(record,kind,folder,'overload',limits);end
    catch exception
        metric=struct('name',name,'expected',expected,'passed',false,'identifier',exception.identifier, ...
            'message',exception.message,'parameters',p);
        results{number}=metric;write(fullfile(folder,'progress.json'),results(1:number));
        rethrow(exception);
    end
    results{number}=metric;write(fullfile(folder,'progress.json'),results(1:number));
    fprintf('OPEN_LOOP_%s %s passed speedRMS=%.6g peakI=%.6g fault=%g\n',upper(kind),name,metric.speed_rms,metric.physical_current_peak,metric.final_fault);
end
assert(~isempty(default)&&~isempty(counter));
p=default.parameters;p.experimentCfg.Step=p.experimentCfg.Step/2;p=refresh_open_loop_app_parameters(p);
refined=run_open_loop_app_case(kind,p,default.stimulus);c=default.columns;
tail=default.time>=default.time(end)-limits.SteadyWindow;
speedDifference=abs(mean(default.trace(tail,c.speed_mechanical))-mean(refined.trace(tail,c.speed_mechanical)));
currentDifference=abs(max(default.physical_trace(:,1))-max(refined.physical_trace(:,1)));
assert(speedDifference<limits.StepSpeedMeanTolerance&&currentDifference<limits.StepCurrentPeakTolerance);
summary=struct('status','passed','release',version('-release'),'kind',kind,'model',spec.model,'cases',numel(results),'results',{results}, ...
    'step_convergence',struct('coarse_step_s',default.parameters.experimentCfg.Step,'fine_step_s',p.experimentCfg.Step, ...
    'mean_speed_difference_rad_s',speedDifference,'peak_current_difference_A',currentDifference,'passed',true), ...
    'raw_MAT_written',false,'metrics_computed_before_decimation',true,'limits',limits);
write(fullfile(folder,'results.json'),summary);
end
function metric=score(r,limits,expected)
c=r.columns;x=r.trace;t=r.time;p=r.parameters;tail=t>=t(end)-limits.SteadyWindow;
reference=x(:,c.frequency_control)*2*pi/p.motorCfg.PolePairs;speed=x(:,c.speed_mechanical);
phase=unwrap(x(:,c.theta_control)-x(:,c.theta_true));phaseTail=phase(tail);
metric=struct('speed_rms',sqrt(mean((speed(tail)-reference(tail)).^2)), ...
    'speed_mean',mean(speed(tail)),'reference_mean',mean(reference(tail)), ...
    'phase_travel',max(phaseTail)-min(phaseTail),'physical_current_peak',max(r.physical_trace(:,1)), ...
    'physical_current_minimum',min(r.physical_trace(:,1)),'max_equation_residual',max(r.physical_trace(:,4)), ...
    'minimum_voltage_scale',min(x(:,c.voltage_scale)),'final_fault',x(end,c.fault), ...
    'final_stage',x(end,c.stage),'current_rms',NaN);
assert(metric.max_equation_residual<limits.EquationResidualLimit,'Physical voltage balance residual exceeded limit.');
duty=x(:,c.duty);assert(all(duty>=p.powerCfg.MinDuty-limits.DutyTolerance&duty<=1-p.powerCfg.MinDuty+limits.DutyTolerance,'all'));
voltage=sqrt(sum(x(:,c.voltage_limited).^2,2));bus=x(:,c.bus_voltage);
assert(all(voltage<=bus*p.inverterCfg.LinearLimit+1e-9),'Final dq voltage exceeds actual bus reserve.');
assert(all(abs(x(:,c.frequency_control))<=p.openLoopCfg.MaximumFrequency+1e-10));
run=x(:,c.stage)==3;pair=run(1:end-1)&run(2:end)&x(1:end-1,c.enable)==1&x(2:end,c.enable)==1&x(1:end-1,c.reset)==0&x(2:end,c.reset)==0;
increment=diff(x(:,c.frequency_control));assert(all(abs(increment(pair))<=p.openLoopCfg.FrequencySlew*p.currentCfg.Ts+1e-10));
disabled=x(:,c.enable)==0|x(:,c.reset)==1;assert(all(x(disabled,c.pwm_enable)==0));
assert(isequal(x(:,c.bridge_mode),x(:,c.pwm_enable)),'Bridge mode must be 0=all-off, 1=average PWM.');
if isfield(c,'current_error'),metric.current_rms=sqrt(mean(sum(x(tail,c.current_error).^2,2)));end
switch expected
    case 'tracking'
        assert(all(x(:,c.fault)==0)&&all(x(tail,c.stage)==3));
        assert(metric.physical_current_peak>.2,'No physical current was produced.');
        assert(metric.speed_rms<limits.SpeedRmsLimit,'Physical rotor did not track the software synchronous speed.');
        assert(metric.phase_travel<limits.PhaseTravelLimit,'Phase drift is inconsistent with synchronization.');
        assert(metric.physical_current_peak<p.openLoopCfg.CurrentTrip);
        if isfield(c,'current_error'),assert(metric.current_rms<limits.CurrentRmsLimit,'I-f current tracking failed.');end
    case 'refused'
        assert(all(x(:,c.pwm_enable)==0)&&metric.final_fault==3);
    case 'current_trip'
        first=find(x(:,c.fault)>0,1);assert(~isempty(first)&&metric.final_fault==1&&all(x(first:end,c.pwm_enable)==0));
    case 'event_refused'
        after=t>=limits.EventTime;assert(all(x(after,c.pwm_enable)==0)&&metric.final_fault==3);
        event=find(t>=limits.EventTime,1);assert(abs(speed(event)-speed(event-1))<1,'Reset forced a discontinuity in physical speed.');
    case 'counterexample'
        assert(metric.speed_rms>limits.SpeedRmsLimit||metric.phase_travel>limits.PhaseTravelLimit||metric.final_fault>0, ...
            'The overload did not demonstrate the expected limitation.');
    case 'voltage_counterexample'
        assert(metric.minimum_voltage_scale<.99||any(x(:,c.amplitude_limited)>0),'No voltage constraint was exercised.');
        assert(metric.speed_rms>limits.SpeedRmsLimit||metric.phase_travel>limits.PhaseTravelLimit||metric.final_fault>0);
end
end
function export(r,kind,folder,name,limits)
defs=open_loop_app_channels(kind);headers={'time_s'};for k=1:size(defs,1)
    for j=1:defs{k,2},if defs{k,2}==1,headers{end+1}=defs{k,1};else,headers{end+1}=sprintf('%s_%d',defs{k,1},j);end,end
end
stride=max([1,ceil(r.parameters.experimentCfg.LogPeriod/r.parameters.currentCfg.Ts),ceil(numel(r.time)/limits.ExportMaximumRows)]);
idx=unique([1:stride:numel(r.time),numel(r.time)]);
tableData=array2table([r.time(idx),r.trace(idx,:)],'VariableNames',headers);
writetable(tableData,fullfile(folder,[name '_view.csv']));
c=r.columns;f=figure('Visible','off','Position',[100,100,1000,900]);cleanup=onCleanup(@()close(f));t=r.time(idx);x=r.trace(idx,:);
tiledlayout(4,1);nexttile;plot(t,[x(:,c.speed_mechanical),2*pi*x(:,c.frequency_control)/r.parameters.motorCfg.PolePairs]);ylabel('mechanical rad/s');legend('physical','synchronous');grid on
nexttile;plot(t,x(:,c.current_virtual_dq));ylabel('virtual dq A');legend('d measured','q measured');grid on
nexttile;plot(t,[sqrt(sum(x(:,c.voltage_request).^2,2)),sqrt(sum(x(:,c.voltage_limited).^2,2))]);ylabel('voltage V');legend('requested','limited');grid on
nexttile;plot(t,[x(:,c.stage),x(:,c.fault),x(:,c.pwm_enable)]);ylabel('stage / fault / PWM');xlabel('s');grid on
exportgraphics(f,fullfile(folder,[name '.png']));exportgraphics(f,fullfile(folder,[name '.svg']),'ContentType','vector');
end
function write(file,data)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(data,PrettyPrint=true),'char');
end
