function report=run_flying_foc_validation()
%RUN_FLYING_FOC_VALIDATION Capture both signs and retain explicit refusals.
module=fileparts(fileparts(mfilename('fullpath')));folder=fileparts(mfilename('fullpath'));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'));
base=flying_foc_parameters();cases=struct('name',{},'p',{},'expected',{});
cases(end+1)=item('forward',base,'run');
p=base;p.bridgeCfg.Speed0=-80;p.experimentCfg.SpeedReference=-100;
cases(end+1)=item('reverse',p,'run');
p=base;p.bridgeCfg.Position0=2.7;cases(end+1)=item('initial_angle',p,'run');
p=base;p.experimentCfg.LoadTorque=0.15;cases(end+1)=item('load',p,'run');
p=base;p.bridgeCfg.Vdc=36;p.flyingCfg.CaptureVoltageMax=0.9*36/sqrt(3)*(1-2*p.inverterCfg.MinDuty);
p.experimentCfg.SpeedReference=90;cases(end+1)=item('bus_36V',p,'run');
p=base;p.experimentCfg.ResetTime=0.45;p.experimentCfg.Duration=1.2;
cases(end+1)=item('moving_reset',p,'recapture');
p=base;p.experimentCfg.DisableTime=0.45;p.experimentCfg.ReenableTime=0.6;p.experimentCfg.Duration=1.3;
cases(end+1)=item('moving_disable',p,'recapture');
p=base;p.experimentCfg.ObserverOffTime=0.6;p.experimentCfg.LoadTorque=0.15;p.experimentCfg.LoadTime=0.35;
cases(end+1)=item('observer_loss',p,'loss');
p=base;p.bridgeCfg.Speed0=-80;cases(end+1)=item('opposite_target',p,'opposite');
p=base;p.bridgeCfg.Speed0=0;cases(end+1)=item('stationary',p,'timeout');
p=base;p.bridgeCfg.Speed0=180;cases(end+1)=item('voltage_headroom',p,'voltage');
p=base;p.bridgeCfg.Speed0=400;cases(end+1)=item('diode_rectification',p,'rectification');
p=base;p.bridgeCfg.Ts=base.bridgeCfg.Ts/2;cases(end+1)=item('half_plant_step',p,'run');
results=struct('name',{},'expected',{},'passed',{},'metrics',{});
for k=1:numel(cases)
    [out,p]=run_flying_foc_case(cases(k).p);
    plant=out.plant_trace;observer=out.observer_trace;controller=out.controller_trace;
    metrics=analyze(plant,observer,controller,p,cases(k).expected);
    name=cases(k).name;expected=cases(k).expected;
    save(fullfile(folder,['flying_',name,'.mat']),'plant','observer','controller','p','metrics','expected','-v7');
    results(k)=struct('name',name,'expected',expected,'passed',true,'metrics',metrics); %#ok<AGROW>
    fprintf('%s PASS, capture %.6g s, peak %.6g A, fault %.0f\n',name,metrics.capture_time,metrics.peak_phase_current,metrics.final_fault);
end
report=struct('release',version,'model','FlyingFluxFOC','cases',results,'count',numel(results));
writeJson(fullfile(folder,'flying_results.json'),report);
close_system('FlyingFluxFOC',0);
end
function value=item(name,p,expected)
value=struct('name',name,'p',p,'expected',expected);
end
function m=analyze(plant,observer,controller,p,expected)
t=plant.time;assert(isequal(t,observer.time) && isequal(t,controller.time));
assert(all(isfinite(plant.signals.values),'all') && all(isfinite(observer.signals.values),'all') && all(isfinite(controller.signals.values),'all'));
sequence=signal(controller,'controller','sequence');mode=signal(plant,'plant','bridge_mode');
phase=signal(plant,'plant','phase_current');speed=signal(plant,'plant','speed_m');
theta=signal(plant,'plant','theta_e');thetaUsed=signal(observer,'observer','theta_used');
angleError=atan2(sin(thetaUsed-theta),cos(thetaUsed-theta));
assert(max(abs(sum(phase,2)))<1e-8);
assert(max(signal(plant,'plant','equation_residual'))<1e-6);
assert(all(ismember(mode,[0,1])) && all(mode(sequence(:,7)~=3)==0));
assert(all(signal(controller,'controller','duty_abc')>=p.inverterCfg.MinDuty-1e-12,'all'));
assert(all(signal(controller,'controller','duty_abc')<=1-p.inverterCfg.MinDuty+1e-12,'all'));
run=mode==1;turnOn=find(diff([0;mode])==1);turnOff=find(diff([0;mode])==-1);
m=struct('capture_time',NaN,'capture_count',numel(turnOn),'turn_off_count',numel(turnOff), ...
    'peak_phase_current',max(abs(phase),[],'all'),'final_fault',sequence(end,8), ...
    'angle_rms',NaN,'speed_final',mean(speed(t>=t(end)-0.1)), ...
    'peak_capture_current',NaN,'enable_voltage_mismatch',NaN, ...
    'returned_bus_energy',-trapz(t,min(signal(plant,'plant','dc_current'),0))*p.bridgeCfg.Vdc);
if any(run)
    m.capture_time=t(turnOn(1));window=t>=t(end)-0.2 & run;
    if any(window),m.angle_rms=sqrt(mean(angleError(window).^2));end
    opening=t>=m.capture_time & t<=m.capture_time+0.005;
    m.peak_capture_current=max(abs(phase(opening,:)),[],'all');
    voltage=signal(observer,'observer','sampled_voltage_ab');raw=signal(observer,'observer','theta_raw');
    passiveDQ=[cos(raw).*voltage(:,1)+sin(raw).*voltage(:,2),-sin(raw).*voltage(:,1)+cos(raw).*voltage(:,2)];
    request=signal(controller,'controller','pi_voltage');
    m.enable_voltage_mismatch=norm(request(turnOn(1),:)-passiveDQ(turnOn(1),:));
    assert(m.enable_voltage_mismatch<0.3,'PI was not precharged to the passive voltage.');
    assert(m.peak_capture_current<1,'Unexpected flying-capture current surge.');
end
switch expected
    case {'run','recapture'}
        assert(any(run) && mode(end)==1 && all(sequence(:,8)==0));
        assert(m.angle_rms<0.08 && abs(m.speed_final-p.experimentCfg.SpeedReference)<3);
        assert(m.peak_phase_current<p.flyingCfg.CurrentTrip);
        if strcmp(expected,'recapture')
            assert(numel(turnOn)>=2 && numel(turnOff)>=1);
            assert(abs(speed(turnOff(1)))>30,'Controller reset must not reset physical speed.');
        end
    case 'loss'
        assert(any(run) && mode(end)==0 && sequence(end,8)==5);
        assert(t(turnOff(end))<=p.experimentCfg.ObserverOffTime+p.flyingCfg.LossTime+2*p.currentCfg.Ts);
        % This trace retains the physical all-gates-off current and diodes.
        assert(any(abs(signal(plant,'plant','diode_states'))>0,'all'));
    case 'opposite'
        assert(~any(run) && sequence(end,8)==2);
    case 'timeout'
        assert(~any(run) && sequence(end,8)==1 && m.peak_phase_current<1e-9);
    case 'voltage'
        assert(~any(run) && sequence(end,8)==3);
    case 'rectification'
        assert(~any(run) && any(abs(signal(plant,'plant','diode_states'))>0,'all'));
        assert(m.peak_phase_current>1 && m.returned_bus_energy>0);
    otherwise,error('Unknown acceptance case.');
end
end
function values=signal(trace,scope,name)
definitions=flying_foc_channels(scope);row=find(strcmp(definitions(:,1),name));assert(isscalar(row));
widths=cell2mat(definitions(:,2));first=1+sum(widths(1:row-1));
values=trace.signals.values(:,first:first+widths(row)-1);
end
function writeJson(destination,value)
file=fopen(destination,'w','n','UTF-8');assert(file>=0);cleanup=onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(value,'PrettyPrint',true));
end
