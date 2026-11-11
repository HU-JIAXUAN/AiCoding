function report=run_hfi_foc_validation()
%RUN_HFI_FOC_VALIDATION Physical HFI-started current/speed/torque FOC MIL.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SensorlessHFIFOC';load_system(fullfile(module,'src',[model,'.slx']));
modelCleanup=onCleanup(@()close_system(model,0));
names={'nominal','negative_speed','opposite_polarity','negative_axis','zero_speed_hold','torque_mode', ...
    'adc_noise_12bit','execution_delay','current_delay_aligned','current_delay_unaligned','half_actual_voltage', ...
    'load_reversal','command_reversal','current_limit_recovery','disable_restart','reset_during_probe', ...
    'qualification_lost','current_fault','no_saturation','isotropic','known_cross_inductance', ...
    'unknown_cross_inductance','insufficient_voltage','wrong_nominal_average'};
streams={'plant_trace','probe_trace','axis_trace','polarity_trace','controller_trace','voltage_trace','adc_trace','angle_error','state_trace'};
widths=[10,16,15,16,25,8,4,1,10];records=struct();metrics=cell(size(names));
for test=1:numel(names)
    name=names{test};p=hfi_foc_app_parameters();
    switch name
        case 'negative_speed',p.Test.SpeedReference=-8;p.Test.LoadTorque=-.02;
        case 'opposite_polarity',p.Test.InitialElectricalAngle=.7+pi;
        case 'negative_axis',p.Test.InitialElectricalAngle=-.9;
        case 'zero_speed_hold',p.Test.SpeedReference=0;
        case 'torque_mode',p.Test.Mode=0;p.Test.TorqueReference=.005;p.Test.LoadTorque=.005;p.Test.LoadTime=.35;p.Test.Duration=.9;
        case 'adc_noise_12bit',p.Test.MeasurementNoise=.001;p.Test.CurrentResolution=16/4096;
        case 'execution_delay',p.Test.ExecutionDelay=1;
        case 'current_delay_aligned',p.Test.CurrentDelay=1;p.Test.VoltageAlignmentDelay=1;
        case 'current_delay_unaligned',p.Test.CurrentDelay=1;
        case 'half_actual_voltage',p.Test.ActuationGain=.5;
        case 'load_reversal',p.Test.Duration=1.4;
        case 'command_reversal',p.Test.Duration=1.6;p.Test.LoadTorque=0;
        case 'current_limit_recovery',p.Test.Duration=1.6;p.Test.LoadTorque=0;p.FOC.CurrentMax=.15;
        case 'disable_restart',p.Test.Duration=1.7;p.Test.LoadTorque=0;
        case {'qualification_lost','current_fault'},p.Test.Duration=1;
        case 'no_saturation',p.Motor.SaturationDepth=0;
        case 'isotropic',p.Motor.SaturationDepth=0;p.Motor.Lq=p.Motor.Ld;
        case 'known_cross_inductance',p.Motor.CrossInductance=.2e-3;p.HFI.CrossInductance=.2e-3;
        case 'unknown_cross_inductance',p.Motor.CrossInductance=.2e-3;
        case 'insufficient_voltage',p.Inverter.Vdc=1;
        case 'wrong_nominal_average',p.HFI.Ld=2e-3;p.HFI.Lq=3e-3;
    end
    p.Motor.Position0=p.Test.InitialElectricalAngle/p.Motor.PolePairs;p.Motor=refresh_pmsm_hf_parameters(p.Motor);
    p.HFI=refresh_hfi_parameters(p.HFI);p.PLL=hfi_pll_parameters(p.HFI);
    p.Probe.CrossPhase=p.HFI.CrossPhase;p.Probe=refresh_hfi_probe_parameters(p.Probe);
    p.Inverter.LinearLimit=p.Inverter.Vdc/sqrt(3)*(1-2*p.Inverter.MinDuty);
    stimulus=hfi_foc_stimulus(p.Test);time=stimulus.time;sample=round(time/p.Test.Ts);
    switch name
        case 'load_reversal',stimulus.signals.values(time>=.9,1)=-.02;
        case 'command_reversal',stimulus.signals.values(time>=.65,8)=-8;
        case 'current_limit_recovery',stimulus.signals.values(time>=.6 & time<.8,1)=.05;
        case 'disable_restart',stimulus.signals.values(time>=.6 & time<.8,2)=0;
        case 'reset_during_probe',stimulus.signals.values(sample==80,3)=1;
        case 'qualification_lost',stimulus.signals.values(time>=.6,7)=0;
        case 'current_fault'
            stimulus.signals.values(time>=.6,4)=stimulus.signals.values(time>=.6,4)+20;
            stimulus.signals.values(time>=.6,5)=stimulus.signals.values(time>=.6,5)-20;
    end
    values=struct('hfiCfg',p.HFI,'pllCfg',p.PLL,'probeCfg',p.Probe,'polarityCfg',p.Polarity, ...
        'hfPlantCfg',p.Motor,'pmsmCfg',p.Motor,'hfiFocTestCfg',p.Test,'currentCfg',p.Current,'inverterCfg',p.Inverter, ...
        'feedforwardCfg',p.Feedforward,'motionCfg',p.Motion,'profileCfg',p.Profile,'focCfg',p.FOC,'refCfg',p.Reference,'testStim',stimulus);
    input=Simulink.SimulationInput(model);fields=fieldnames(values);
    for k=1:numel(fields),input=input.setVariable(fields{k},values.(fields{k}),'Workspace',model);end
    input=input.setModelParameter('StopTime',num2str(p.Test.Duration,16));
    record=struct('name',name,'parameters',values);metric=struct('name',name,'status','failed');fprintf('HFI FOC running %s\n',name);
    try
        timer=tic;output=sim(input);record.wall_time_s=toc(timer);record.time=output.plant_trace.time;
        assert(numel(record.time)==numel(time) && max(abs(record.time-time))<1e-10);
        for k=1:numel(streams)
            signal=output.(streams{k});assert(size(signal.signals.values,2)==widths(k));
            assert(isequal(signal.time,record.time) && all(isfinite(signal.signals.values),'all'));
            record.(streams{k})=signal.signals.values;
        end
        plant=record.plant_trace;ctrl=record.controller_trace;state=record.state_trace;
        pole=record.polarity_trace;voltage=record.voltage_trace;probe=record.probe_trace;
        tail=time>=p.Test.Duration-.2;mechanical=plant(:,4)/p.Motor.PolePairs;
        currentError=ctrl(:,[7,6])-ctrl(:,8:9);
        first=find(state(:,4)>.5,1);
        metric=struct('name',name,'speed_rms_rad_s',sqrt(mean((mechanical(tail)-ctrl(tail,1)).^2)), ...
            'estimated_speed_rms_rad_s',sqrt(mean((ctrl(tail,2)-mechanical(tail)).^2)), ...
            'angle_rms_rad',sqrt(mean(record.angle_error(tail).^2)), ...
            'current_dq_rms_A',sqrt(mean(sum(currentError(tail,:).^2,2))), ...
            'valid_fraction',mean(pole(tail,5)>.5),'control_active_fraction',mean(state(tail,4)>.5), ...
            'fault_code',state(end,7),'maximum_polarity_fault',max(pole(:,14)), ...
            'final_probe_qualified',probe(end,5),'probe_quality_code',probe(end,16), ...
            'maximum_physical_current_A',max(hypot(plant(:,1),plant(:,2))), ...
            'maximum_measured_current_A',max(hypot(ctrl(:,8),ctrl(:,9))), ...
            'maximum_actual_voltage_V',max(hypot(voltage(:,1),voltage(:,2))), ...
            'mean_torque_Nm',mean(plant(tail,5)),'final_speed_rad_s',mechanical(end), ...
            'first_control_s',NaN,'status','observed');
        if ~isempty(first),metric.first_control_s=time(first);end
        assert(max(abs(ctrl(:,6)))<=p.FOC.CurrentMax+1e-12);
        assert(metric.maximum_actual_voltage_V<=p.Inverter.LinearLimit*abs(p.Test.ActuationGain)+1e-9);
        assert(all(voltage(:,5:7)>=p.Inverter.MinDuty-1e-12,'all') && all(voltage(:,5:7)<=1-p.Inverter.MinDuty+1e-12,'all'));
        % Verify the actual outer-integral update grid, not only block settings.
        changed=find(diff(ctrl(:,23))~=0)+1;
        assert(all(abs(time(changed)/p.Reference.SpeedTs-round(time(changed)/p.Reference.SpeedTs))<1e-7));
        switch name
            case {'current_delay_unaligned','isotropic','insufficient_voltage'}
                assert(metric.final_probe_qualified==0 && all(state(:,4)==0));
            case 'no_saturation'
                assert(metric.maximum_polarity_fault==5 && all(state(:,4)==0));
            case 'qualification_lost'
                assert(metric.fault_code==2 && metric.control_active_fraction==0 && metric.maximum_polarity_fault==6);
            case 'current_fault',assert(metric.fault_code==1 && metric.control_active_fraction==0);
            case 'unknown_cross_inductance'
                assert(metric.angle_rms_rad>.2 && metric.valid_fraction>.9);
            case 'torque_mode'
                assert(abs(metric.mean_torque_Nm-p.Test.TorqueReference)<.001 && metric.angle_rms_rad<.08 && metric.valid_fraction>.95);
                assert(all(ctrl(:,23)==0));
            otherwise
                assert(metric.speed_rms_rad_s<.5 && metric.angle_rms_rad<.08 && metric.current_dq_rms_A<.3);
                assert(metric.valid_fraction>.95 && metric.control_active_fraction>.95 && metric.fault_code==0);
        end
        if ismember(name,{'current_delay_unaligned','isotropic','insufficient_voltage','no_saturation','qualification_lost','current_fault'})
            assert(all(abs(voltage(end,1:2))<1e-12) && all(ctrl(end,14:15)==0));
        end
        if strcmp(name,'current_limit_recovery')
            assert(max(abs(ctrl(:,25)))>p.FOC.CurrentMax+.01 && max(abs(ctrl(:,24)))>.001);
        elseif strcmp(name,'disable_restart')
            off=time>=.6 & time<.8;assert(all(state(off,4)==0) && all(voltage(off,1:2)==0,'all'));
            assert(any(state(time>.8,4)>.5));
        elseif strcmp(name,'reset_during_probe')
            at=sample==80;assert(all(state(at,4)==0) && all(voltage(at,1:2)==0,'all'));
        end
        metric.status='passed';
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');metric.status='failed';metric.error=record.error;
    end
    records.(name)=record;metrics{test}=metric;fprintf('%s\n',jsonencode(metric));
end
report=struct('release',version('-release'),'root',matlabroot,'kind','MIL physical nonlinear PMSM; HFI-started FOC', ...
    'tests',numel(names),'passed',sum(cellfun(@(x)strcmp(x.status,'passed'),metrics)),'metrics',{metrics});
save(fullfile(module,'waveform_analysis','foc_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','foc_metrics.json'),'w');fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
assert(report.passed==report.tests,'Some HFI FOC cases failed; inspect physical records.');
end
