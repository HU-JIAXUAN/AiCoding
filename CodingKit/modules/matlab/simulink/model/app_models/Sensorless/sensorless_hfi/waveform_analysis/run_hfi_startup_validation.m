function report=run_hfi_startup_validation()
%RUN_HFI_STARTUP_VALIDATION Physical MIL of qualification, axis and polarity.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
model='SensorlessHFIStartup';load_system(fullfile(module,'src',[model,'.slx']));
modelCleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'nominal','opposite_polarity','negative_axis','near_quadrature', ...
    'wrong_nominal_average','adc_noise_12bit','no_saturation','isotropic', ...
    'unequal_actual_pulses','half_actual_voltage','execution_delay', ...
    'current_delay_aligned','current_delay_unaligned','moving_shaft', ...
    'disable_reacquire','reset_reacquire','current_fault','qualification_lost', ...
    'known_cross_inductance','unknown_cross_inductance','disable_during_probe','reset_during_probe'};
records=struct();metrics=cell(size(names));
for test=1:numel(names)
    name=names{test};configuration=hfi_startup_app_parameters();
    switch name
        case 'opposite_polarity',configuration.Test.InitialElectricalAngle=.7+pi;
        case 'negative_axis',configuration.Test.InitialElectricalAngle=-.9;
        case 'near_quadrature',configuration.Test.InitialElectricalAngle=1.5;
        case 'wrong_nominal_average',configuration.HFI.Ld=2e-3;configuration.HFI.Lq=3e-3;
        case 'adc_noise_12bit',configuration.Test.MeasurementNoise=.001;configuration.Test.CurrentResolution=16/4096;
        case 'no_saturation',configuration.Motor.SaturationDepth=0;
        case 'isotropic',configuration.Motor.SaturationDepth=0;configuration.Motor.Lq=configuration.Motor.Ld;
        case 'unequal_actual_pulses',configuration.Test.PulseNegativeGain=.7;
        case 'half_actual_voltage',configuration.Test.ActuationGain=.5;
        case 'execution_delay',configuration.Test.ExecutionDelay=1;
        case 'current_delay_aligned',configuration.Test.CurrentDelay=1;configuration.Test.VoltageAlignmentDelay=1;
        case 'current_delay_unaligned',configuration.Test.CurrentDelay=1;
        case 'moving_shaft',configuration.Motor.Speed0=5/configuration.Motor.PolePairs;
        case {'disable_reacquire','reset_reacquire'},configuration.Test.Duration=.45;
        case 'current_fault',configuration.Test.PulseFaultOffsetA=20;
        case 'known_cross_inductance'
            configuration.Motor.CrossInductance=.2e-3;configuration.HFI.CrossInductance=.2e-3;
        case 'unknown_cross_inductance',configuration.Motor.CrossInductance=.2e-3;
    end
    configuration.HFI=refresh_hfi_parameters(configuration.HFI);configuration.PLL=hfi_pll_parameters(configuration.HFI);
    configuration.Probe.CrossPhase=configuration.HFI.CrossPhase;
    configuration.Probe=refresh_hfi_probe_parameters(configuration.Probe);
    configuration.Motor.Position0=configuration.Test.InitialElectricalAngle/configuration.Motor.PolePairs;
    configuration.Motor=refresh_pmsm_hf_parameters(configuration.Motor);
    if strcmp(name,'moving_shaft')
        motor=configuration.Motor;
        configuration.Test.LoadTorque=-motor.B*motor.Speed0-1.5*motor.PolePairs^2*motor.Flux^2*motor.Speed0/motor.Rs;
    end
    stimulus=hfi_startup_stimulus(configuration.Test);sample=round(stimulus.time/configuration.Test.Ts);
    if strcmp(name,'disable_reacquire'),stimulus.signals.values(sample>=2400 & sample<2800,2)=0;end
    if strcmp(name,'reset_reacquire'),stimulus.signals.values(sample==2400,3)=1;end
    if strcmp(name,'qualification_lost'),stimulus.signals.values(sample>=4600,7)=0;end
    if strcmp(name,'disable_during_probe'),stimulus.signals.values(sample>=80 & sample<240,2)=0;end
    if strcmp(name,'reset_during_probe'),stimulus.signals.values(sample==80,3)=1;end
    values=struct('hfiCfg',configuration.HFI,'pllCfg',configuration.PLL,'probeCfg',configuration.Probe, ...
        'polarityCfg',configuration.Polarity,'hfPlantCfg',configuration.Motor,'hfiStartupTestCfg',configuration.Test,'testStim',stimulus);
    input=Simulink.SimulationInput(model);fields=fieldnames(values);
    for k=1:numel(fields),input=input.setVariable(fields{k},values.(fields{k}),'Workspace',model);end
    input=input.setModelParameter('StopTime',num2str(configuration.Test.Duration,16));
    record=struct('name',name,'parameters',values);metric=struct('name',name,'status','failed');
    fprintf('HFI startup running %s\n',name);
    try
        timer=tic;output=sim(input);record.wall_time_s=toc(timer);
        streams={'plant_trace','probe_trace','axis_trace','polarity_trace','error_trace','adc_trace'};
        widths=[13,16,15,16,2,4];record.time=output.plant_trace.time;
        for k=1:numel(streams)
            signal=output.(streams{k});assert(size(signal.signals.values,2)==widths(k));
            assert(all(isfinite(signal.signals.values),'all'));
            assert(isequal(signal.time,record.time));record.(streams{k})=signal.signals.values;
        end
        plant=record.plant_trace;probe=record.probe_trace;axis=record.axis_trace;pole=record.polarity_trace;
        tail=record.time>=configuration.Test.Duration-.05;
        metric=struct('name',name,'full_angle_rms_rad',sqrt(mean(record.error_trace(tail,2).^2)), ...
            'axis_rms_rad',sqrt(mean(record.error_trace(tail,1).^2)), ...
            'valid_fraction',mean(pole(tail,5)>.5),'polarity_known',pole(end,6), ...
            'flip_pi',pole(end,7),'final_stage',pole(end,8),'fault_code',pole(end,14), ...
            'peak_positive_A',pole(end,9),'peak_negative_A',pole(end,10),'peak_difference_A',pole(end,11), ...
            'dose_positive_Vs',pole(end,12),'dose_negative_Vs',pole(end,13), ...
            'probe_qualified',probe(end,5),'probe_quality_code',probe(end,16), ...
            'inverse_average_measured_H_inv',probe(end,7),'max_current_A',max(hypot(plant(:,3),plant(:,4))), ...
            'max_rotor_movement_rad',max(abs(unwrap(plant(:,5))-plant(1,5))), ...
            'mean_physical_speed_rad_s',mean(plant(tail,6)),'first_valid_s',NaN,'status','observed');
        first=find(pole(:,5)>.5,1);if ~isempty(first),metric.first_valid_s=record.time(first);end
        switch name
            case {'isotropic','current_delay_unaligned'}
                assert(metric.probe_qualified==0 && metric.polarity_known==0 && metric.valid_fraction==0);
            case 'no_saturation',assert(metric.fault_code==5 && metric.polarity_known==0 && metric.valid_fraction==0);
            case 'unequal_actual_pulses',assert(metric.fault_code==4 && metric.polarity_known==0 && metric.valid_fraction==0);
            case 'moving_shaft'
                assert(metric.fault_code==2 && metric.polarity_known==0 && metric.valid_fraction==0);
                assert(abs(metric.mean_physical_speed_rad_s)>2);
            case 'current_fault',assert(metric.fault_code==1 && metric.polarity_known==0 && metric.valid_fraction==0);
            case 'qualification_lost',assert(metric.fault_code==6 && metric.valid_fraction==0);
            case 'unknown_cross_inductance'
                assert(metric.probe_qualified==1 && metric.axis_rms_rad>.2);
            otherwise
                assert(metric.full_angle_rms_rad<.08 && metric.valid_fraction>.9 && metric.polarity_known==1 && metric.fault_code==0);
                assert(min(pole(end,12:13))>=configuration.Polarity.MinPulseDose);
                assert(abs(pole(end,12)-pole(end,13))/mean(pole(end,12:13))<=configuration.Polarity.MaxDoseMismatch);
        end
        if ismember(name,{'no_saturation','unequal_actual_pulses','moving_shaft','current_fault','qualification_lost','isotropic','current_delay_unaligned'})
            assert(all(abs(plant(end,1:2))<1e-12),'Final requested average voltage was not zero.');
        end
        if strcmp(name,'disable_reacquire')
            off=sample>=2400 & sample<2800;assert(all(pole(off,5:6)==0,'all') && all(plant(off,1:2)==0,'all'));
        elseif strcmp(name,'reset_reacquire')
            at=sample==2400;assert(all(pole(at,5:6)==0,'all') && all(plant(at,1:2)==0,'all'));
        elseif strcmp(name,'disable_during_probe')
            off=sample>=80 & sample<240;assert(all(pole(off,5:6)==0,'all') && all(plant(off,1:2)==0,'all'));
        elseif strcmp(name,'reset_during_probe')
            at=sample==80;assert(all(pole(at,5:6)==0,'all') && all(plant(at,1:2)==0,'all'));
        end
        if ismember(name,{'nominal','opposite_polarity','wrong_nominal_average','execution_delay'})
            used=axis(tail,15)>0;assert(all(abs(axis(tail,15)-probe(tail,7))<1e-8 | ~used));
            if strcmp(name,'opposite_polarity'),assert(metric.flip_pi==1);else,assert(metric.flip_pi==0);end
        end
        % ProbeSnapshot is a one-sample handoff: the first stopped sample may
        % still receive the reset result produced while the stage was enabled.
        held=find(plant(:,13)==0 & [false;plant(1:end-1,13)==0]);
        assert(isequal(probe(held,:),probe(held-1,:)),'Disabled probe snapshot must be held.');
        metric.status='passed';
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');metric.status='failed';metric.error=record.error;
    end
    records.(name)=record;metrics{test}=metric;fprintf('%s\n',jsonencode(metric));
end
report=struct('release',version('-release'),'root',matlabroot,'kind','MIL physical HFI startup; no torque controller', ...
    'tests',numel(names),'passed',sum(cellfun(@(x)strcmp(x.status,'passed'),metrics)),'metrics',{metrics});
save(fullfile(module,'waveform_analysis','startup_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','startup_metrics.json'),'w');fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
assert(report.passed==report.tests,'Some HFI startup checks failed; inspect recorded traces.');
end
