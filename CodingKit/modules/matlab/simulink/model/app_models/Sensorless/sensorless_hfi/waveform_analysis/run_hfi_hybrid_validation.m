function report=run_hfi_hybrid_validation(selectedCases,simulationMode)
%RUN_HFI_HYBRID_VALIDATION Physical voltage/current HFI/EEMF integration MIL.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SensorlessHFIHybrid';load_system(fullfile(module,'src',[model,'.slx']));
cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'round_trip','negative_round_trip','opposite_polarity','shifted_dwell', ...
    'adc_noise_12bit','execution_delay','aligned_current_delay','half_voltage','emf_rs_mismatch', ...
    'high_gap_overlap','high_loss_high','low_loss_then_stop','adc_current_fault', ...
    'reset_during_probe','disable_restart','command_reverse','unaligned_current_delay','no_saturation'};
plannedCases=names;fullRun=nargin==0 || isempty(selectedCases);
if nargin<2,simulationMode='normal';end
assert(ismember(simulationMode,{'normal','accelerator'}));
if ~fullRun,selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));names=names(ismember(names,selectedCases));end
assert(~isempty(names));records=struct();metrics=struct([]);
streams={'plant_trace','probe_trace','axis_trace','polarity_trace','controller_trace','voltage_trace', ...
    'adc_trace','angle_error','state_trace','fusion_trace','emf_trace','observer_state_trace'};
widths=[10,16,15,16,25,8,4,1,10,17,12,4];
criteria=struct('speed_rms_rad_s',.5,'angle_rms_rad',.08,'raw_current_dq_rms_A',.3,'active_angle_peak_rad',.25);
for number=1:numel(names)
    name=names{number};p=hfi_hybrid_app_parameters();highWindow=[.95,1.25];
    switch name
        case 'negative_round_trip',p.Test.SpeedReference=-25;p.Test.ReturnSpeed=-8;p.Test.LoadTorque=-.02;
        case 'opposite_polarity',p.Test.InitialElectricalAngle=.7+pi;
        case 'shifted_dwell',p.Test.ReturnTime=1.44;p.Test.Duration=2.4;
        case 'adc_noise_12bit',p.Test.MeasurementNoise=.001;p.Test.CurrentResolution=16/4096;
        case 'execution_delay',p.Test.ExecutionDelay=1;
        case 'aligned_current_delay',p.Test.CurrentDelay=1;p.Test.VoltageAlignmentDelay=1;
        case 'half_voltage',p.Test.ActuationGain=.5;
        case 'emf_rs_mismatch',p.EMF.Rs=1.5*p.EMF.Rs;
        case 'low_loss_then_stop',p.Test.ReturnSpeed=0;
        case 'disable_restart'
            p.Test.Duration=3;p.Test.ReturnTime=2.1;p.Test.LoadTorque=0;highWindow=[.8,.9];
        case 'command_reverse'
            p.Test.Duration=3.5;p.Test.ReturnTime=2.6;p.Test.ReturnSpeed=-8;p.Test.LoadTorque=0;highWindow=[.8,.9];
        case 'unaligned_current_delay',p.Test.CurrentDelay=1;p.Test.Duration=.5;
        case 'no_saturation',p.Test.SaturationDepth=0;p.Test.Duration=.5;
    end
    p.Motor.Position0=p.Test.InitialElectricalAngle/p.Motor.PolePairs;
    p.Motor.SaturationDepth=p.Test.SaturationDepth;p.Motor=refresh_pmsm_hf_parameters(p.Motor);
    values=hfi_hybrid_workspace(p);stimulus=values.testStim;t=stimulus.time;
    switch name
        case 'high_gap_overlap',stimulus.signals.values(t>=.43 & t<.46,11)=0;
        case 'high_loss_high',stimulus.signals.values(t>=.95,11)=0;
        case 'low_loss_then_stop',stimulus.signals.values(t>=.95,7)=0;
        case 'adc_current_fault'
            stimulus.signals.values(t>=.95,4)=stimulus.signals.values(t>=.95,4)+20;
            stimulus.signals.values(t>=.95,5)=stimulus.signals.values(t>=.95,5)-20;
        case 'reset_during_probe',stimulus.signals.values(round(t/p.Test.Ts)==80,3)=1;
        case 'disable_restart',stimulus.signals.values(t>=.95 & t<1.15,2)=0;
        case 'command_reverse',stimulus.signals.values(t>=.95 & t<p.Test.ReturnTime,8)=-25;
    end
    values.testStim=stimulus;in=Simulink.SimulationInput(model);fields=fieldnames(values);
    for k=1:numel(fields),in=in.setVariable(fields{k},values.(fields{k}),'Workspace',model);end
    in=in.setModelParameter('StopTime',num2str(p.Test.Duration,16),'SimulationMode',simulationMode);
    out=sim(in);r=struct('parameters',p,'stimulus',stimulus,'criteria',criteria,'high_window',highWindow);
    for k=1:numel(streams)
        data=out.(streams{k});r.(streams{k})=log_matrix(data,widths(k));
        assert(all(isfinite(r.(streams{k})),'all'),streams{k});
        if k==1,r.time=data.time;else,assert(isequal(data.time,r.time));end
    end
    t=r.time;plant=r.plant_trace;fusion=r.fusion_trace;state=r.state_trace;control=r.controller_trace;emf=r.emf_trace;
    speed=plant(:,4)/p.Motor.PolePairs;error=wrap(fusion(:,1)-plant(:,3));
    assert(max(abs(wrap(r.angle_error-error)))<1e-10,'The logged angle error must use the actual fused angle.');
    high=t>=highWindow(1) & t<=highWindow(2);low=t>=p.Test.Duration-.2;
    currentError=(plant(:,6)-control(:,7)).^2+(plant(:,7)-control(:,6)).^2;
    active=state(:,4)>.5;
    highSpeedRms=sqrt(mean((speed(high)-control(high,1)).^2));
    lowSpeedRms=sqrt(mean((speed(low)-control(low,1)).^2));
    highAngleRms=sqrt(mean(error(high).^2));lowAngleRms=sqrt(mean(error(low).^2));
    first=find(active,1);firstTime=NaN;if ~isempty(first),firstTime=t(first);end
    metric=struct('name',name,'first_control_s',firstTime,'high_speed_rms_rad_s',highSpeedRms, ...
        'low_speed_rms_rad_s',lowSpeedRms,'high_angle_rms_rad',highAngleRms,'low_angle_rms_rad',lowAngleRms, ...
        'maximum_current_A',max(hypot(plant(:,1),plant(:,2))),'maximum_app_fault',max(state(:,7)), ...
        'maximum_fusion_fault',max(fusion(:,8)),'minimum_injection',min(fusion(:,6)), ...
        'final_beta',fusion(end,5),'final_injection',fusion(end,6),'final_pi_flip',fusion(end,11), ...
        'high_emf_angle_rms_rad',sqrt(mean(wrap(emf(high,1)-plant(high,3)).^2)), ...
        'low_raw_current_dq_rms_A',sqrt(mean(currentError(low))), ...
        'execution_wall_s',out.SimulationMetadata.TimingInfo.ExecutionElapsedWallTime,'status','pending');
    r.angle_error=error;r.metric=metric;records.(name)=r;
    try
        assert(all(fusion(:,[5,6])>=0 & fusion(:,[5,6])<=1,'all'));
        assert(max(abs(fusion(:,1)))<=pi+1e-12 && max(abs(fusion(:,16)))<=p.Fusion.PhaseCorrectionRate*p.Test.Ts+1e-12);
        assert(all(r.voltage_trace(:,5:7)>=p.Inverter.MinDuty-1e-12 & r.voltage_trace(:,5:7)<=1-p.Inverter.MinDuty+1e-12,'all'));
        assert(max(abs(control(:,6)))<=p.FOC.CurrentMax+1e-12);
        expectedExtra=wrap(diff(fusion(:,1))-p.Test.Ts*fusion(1:end-1,2));
        assert(max(abs(wrap(control(2:end,20)-expectedExtra)))<1e-9);
        consecutive=fusion(1:end-1,4)>.5 & fusion(2:end,4)>.5;
        rate=wrap(diff(fusion(:,1)))/p.Test.Ts;
        assert(max([0;abs(rate(consecutive)-fusion(find(consecutive)+1,3))])<1e-7);
        rejected=ismember(name,{'unaligned_current_delay','no_saturation'});
        failed=ismember(name,{'high_loss_high','low_loss_then_stop','adc_current_fault'});
        if rejected
            assert(~any(active) && all(control(:,14:15)==0,'all'));
            if strcmp(name,'no_saturation'),assert(max(r.polarity_trace(:,14))==5);
            else,assert(r.probe_trace(end,6)==1 && r.probe_trace(end,16)==3);end
        elseif failed
            assert(~isempty(first) && state(end,7)>0 && ~active(end));
            assert(all(control(low,14:15)==0,'all'));
            assert(max(abs(r.voltage_trace(low,1:2)),[],'all')<1e-12);
            if strcmp(name,'adc_current_fault'),assert(max(state(:,7))==1);
            else,assert(max(fusion(:,8))==1 && max(state(:,7))==2);end
        else
            assert(~isempty(first) && ~any(state(:,7)>0) && ~any(fusion(:,8)>0));
            assert(highSpeedRms<criteria.speed_rms_rad_s && lowSpeedRms<criteria.speed_rms_rad_s);
            assert(highAngleRms<criteria.angle_rms_rad && lowAngleRms<criteria.angle_rms_rad);
            assert(sqrt(mean(currentError(high)))<criteria.raw_current_dq_rms_A && sqrt(mean(currentError(low)))<criteria.raw_current_dq_rms_A);
            assert(all(active(high)) && all(active(low)) && all(fusion(high,5)>.99) && all(fusion(high,6)<.01));
            assert(all(fusion(low,5)<.01) && all(fusion(low,6)>.99));
            assert(max(abs(error(active & t>=.14)))<criteria.active_angle_peak_rad);
            assert(max(hypot(plant(:,1),plant(:,2)))<p.FOC.MaxMeasuredCurrent);
            if ~strcmp(name,'disable_restart'),assert(all(active(t>=.14)));end
            if strcmp(name,'command_reverse')
                negativeHigh=t>=2.25 & t<=2.5;
                assert(mean(speed(negativeHigh))<-24 && all(fusion(negativeHigh,5)>.99) && all(fusion(negativeHigh,6)<.01));
                assert(r.observer_state_trace(end,1)==-1);
            elseif strcmp(name,'negative_round_trip'),assert(r.observer_state_trace(end,1)==-1);
            elseif strcmp(name,'disable_restart')
                secondHigh=t>=1.95 & t<=2.02;
                assert(all(active(secondHigh)) && all(fusion(secondHigh,5)>.99) && all(fusion(secondHigh,6)<.01));
            end
        end
        metric.status='passed';
    catch failure
        metric.status='failed';records.(name).metric=metric;
        if number==1,metrics=metric;else,metrics(number)=metric;end
        report=make_report('failed');save_report();rethrow(failure)
    end
    records.(name).metric=metric;
    if number==1,metrics=metric;else,metrics(number)=metric;end
    fprintf('%s passed\n',name);
end
report=make_report('passed');save_report();
    function result=make_report(status)
        result=struct('release',version('-release'),'root',matlabroot,'kind','physical nonlinear PMSM HFI/EEMF', ...
            'status',status,'full_run',fullRun,'simulation_mode',simulationMode,'planned_cases',{plannedCases}, ...
            'tests',numel(metrics),'passed',sum(strcmp({metrics.status},'passed')), ...
            'criteria',criteria,'metrics',metrics);
    end
    function save_report()
        if fullRun,prefix='hybrid';else,prefix='hybrid_subset';end
        folder=fullfile(module,'waveform_analysis');save(fullfile(folder,[prefix,'_results.mat']),'records','report','-v7.3');
        handle=fopen(fullfile(folder,[prefix,'_metrics.json']),'w');fwrite(handle,jsonencode(report,PrettyPrint=true));fclose(handle);
    end
end
function value=wrap(angle)
value=atan2(sin(angle),cos(angle));
end
function values=log_matrix(data,width)
count=numel(data.time);raw=data.signals.values;
if size(raw,1)==count,values=reshape(raw,count,[]);
elseif size(raw,ndims(raw))==count,values=reshape(raw,[],count).';
else,error('Unexpected log time dimension.');end
assert(size(values,2)==width,'Unexpected log signal width.');
end
