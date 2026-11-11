function report=run_hfi_axis_validation()
%RUN_HFI_AXIS_VALIDATION Physical current-response MIL, including failure cases.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'), ...
    fullfile(lib,'相位跟踪','parameter'),fullfile(lib,'永磁同步电机','parameter'));
model='HFIAxisTest';load_system(fullfile(module,'src',[model,'.slx']));
modelCleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'nominal_locked','near_quadrature','opposite_polarity','negative_axis', ...
    'free_rotor','positive_low_speed','negative_low_speed','load_step', ...
    'saturation','cross_unknown','cross_known','no_saliency_matched_average', ...
    'no_saliency_wrong_average','constant_phase_offsets','adc_noise_12bit', ...
    'current_delay_unaligned','current_delay_aligned','execution_delay', ...
    'half_actual_voltage','low_actual_voltage','scale_removed','disable','reset','adc_unfiltered', ...
    'measured_average_wrong_nominal','measured_average_missing','measured_average_negative', ...
    'measured_average_nan','nominal_ignores_external_nan','measured_average_isotropic'};
records=struct();metrics=cell(size(names));
for test=1:numel(names)
    name=names{test};cfg=hfi_parameters();fixture=hfi_test_parameters();
    fixture.MechanicalEnabled=0;
    switch name
        case 'near_quadrature',fixture.InitialElectricalAngle=1.5;
        case 'opposite_polarity',fixture.InitialElectricalAngle=0.7+pi;
        case 'negative_axis',fixture.InitialElectricalAngle=-0.9;
        case {'free_rotor','positive_low_speed','negative_low_speed','load_step'},fixture.MechanicalEnabled=1;
        case 'saturation',fixture.SaturationDepth=0.25;
        case 'cross_unknown',fixture.CrossInductance=0.2e-3;
        case 'cross_known',fixture.CrossInductance=0.2e-3;cfg.CrossInductance=fixture.CrossInductance;
        case 'constant_phase_offsets',fixture.CurrentOffset=[0.03;-0.02;0.01];
        case {'adc_noise_12bit','adc_unfiltered'}
            fixture.MeasurementNoise=0.001;fixture.CurrentResolution=16/4096;
            if strcmp(name,'adc_unfiltered'),cfg.DemodFilterEnabled=0;end
        case 'current_delay_unaligned',fixture.CurrentDelay=1;
        case 'current_delay_aligned',fixture.CurrentDelay=1;fixture.VoltageAlignmentDelay=1;
        case 'execution_delay',fixture.ExecutionDelay=1;
        case 'half_actual_voltage',fixture.ActuationGain=0.5;
        case 'low_actual_voltage',fixture.ActuationGain=0.2;
        case 'measured_average_wrong_nominal'
            cfg.Ld=2e-3;cfg.Lq=3e-3;cfg.UseMeasuredInverseAverage=1;
            fixture.ExternalInverseAverage=.5*(1/1e-3+1/1.5e-3);
        case 'measured_average_missing',cfg.UseMeasuredInverseAverage=1;
        case 'measured_average_negative',cfg.UseMeasuredInverseAverage=1;fixture.ExternalInverseAverage=-1;
        case 'measured_average_nan',cfg.UseMeasuredInverseAverage=1;fixture.ExternalInverseAverage=NaN;
        case 'nominal_ignores_external_nan',fixture.ExternalInverseAverage=NaN;
        case 'measured_average_isotropic',cfg.UseMeasuredInverseAverage=1;fixture.ExternalInverseAverage=1000;
    end
    cfg=refresh_hfi_parameters(cfg);tracker=hfi_pll_parameters(cfg);motor=hfi_plant_parameters(fixture);
    switch name
        case 'positive_low_speed',motor.Speed0=5/motor.PolePairs;
        case 'negative_low_speed',motor.Speed0=-5/motor.PolePairs;
        case 'no_saliency_matched_average',motor.Ld=1/cfg.InverseAverage;motor.Lq=motor.Ld;
        case 'no_saliency_wrong_average',motor.Lq=motor.Ld;
        case 'measured_average_isotropic',motor.Lq=motor.Ld;
    end
    motor=refresh_pmsm_hf_parameters(motor);
    if ismember(name,{'positive_low_speed','negative_low_speed'})
        % A prime-mover load sustains the shaft motion against short-circuit drag.
        % No plant angle or speed is fed to the observer or this constant load.
        fixture.LoadTorque=-motor.B*motor.Speed0-1.5*motor.PolePairs^2*motor.Flux^2*motor.Speed0/motor.Rs;
    end
    stimulus=hfi_stimulus(fixture);
    time=stimulus.time;sample=round(time/cfg.Ts);
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    switch name
        case 'load_step',stimulus.signals.values(event(0.12),1)=0.001;
        case 'scale_removed',stimulus.signals.values(event(0.12),2)=0;
        case 'disable',stimulus.signals.values(event(0.10)&~event(0.13),3)=0;
        case 'reset',stimulus.signals.values(sample==round(0.12/cfg.Ts),4)=1;
    end
    input=Simulink.SimulationInput(model);
    values=struct('hfiCfg',cfg,'hfiTestCfg',fixture,'pllCfg',tracker,'hfPlantCfg',motor,'testStim',stimulus);
    fields=fieldnames(values);
    for k=1:numel(fields),input=input.setVariable(fields{k},values.(fields{k}),'Workspace',model);end
    input=input.setModelParameter('StopTime',num2str(fixture.Duration,16));
    record=struct('name',name,'parameters',values);fprintf('HFI axis running %s\n',name);
    try
        timer=tic;output=sim(input);record.wall_time_s=toc(timer);trace=output.trace.signals.values;
        record.time=output.trace.time;record.trace=trace;
        assert(size(trace,2)==38 && all(isfinite(trace),'all'));
        assert(numel(time)==size(trace,1) && max(abs(record.time-time))<1e-11);
        tail=time>=fixture.Duration-0.05;
        metric=struct('name',name,'axis_rms_rad',sqrt(mean(trace(tail,26).^2)), ...
            'full_angle_rms_rad',sqrt(mean(trace(tail,27).^2)), ...
            'speed_rms_rad_s',sqrt(mean((trace(tail,15)-trace(tail,8)).^2)), ...
            'valid_fraction',mean(trace(tail,16)>0.5),'response_A',mean(trace(tail,18)), ...
            'max_current_A',max(abs(trace(:,3:6)),[],'all'), ...
            'mean_physical_speed_rad_s',mean(trace(tail,8)), ...
            'max_rotor_movement_rad',max(abs(unwrap(trace(:,7))-trace(1,7))), ...
            'polarity_identified',false,'status','observed');
        % Record both successful and intentionally invalid/ambiguous cases.
        switch name
            case 'adc_unfiltered'
                assert(metric.axis_rms_rad<0.08 && metric.speed_rms_rad_s>4 && metric.valid_fraction<0.95);
            case {'no_saliency_matched_average','measured_average_isotropic'}
                assert(metric.valid_fraction==0);
            case {'measured_average_missing','measured_average_negative','measured_average_nan'}
                assert(metric.valid_fraction==0 && all(trace(:,38)==0));
            case {'low_actual_voltage','scale_removed'}
                assert(metric.valid_fraction==0);
            case 'opposite_polarity'
                assert(metric.axis_rms_rad<0.03 && metric.full_angle_rms_rad>3);
            case 'cross_unknown'
                assert(metric.axis_rms_rad>0.2);
            case {'no_saliency_wrong_average','current_delay_unaligned'}
                assert(metric.axis_rms_rad>0.2 || metric.valid_fraction<0.1);
            otherwise
                assert(metric.axis_rms_rad<0.08 && metric.speed_rms_rad_s<4 && metric.valid_fraction>0.9);
        end
        if strcmp(name,'measured_average_wrong_nominal')
            assert(max(abs(trace(tail,38)-fixture.ExternalInverseAverage))<1e-10);
        end
        if ismember(name,{'positive_low_speed','negative_low_speed'})
            assert(abs(metric.mean_physical_speed_rad_s)>2,'Sustained low-speed motion was not exercised.');
        end
        if strcmp(name,'disable')
            off=event(0.10)&~event(0.13);assert(all(trace(off,12:13)==0,'all') && all(trace(off,16)==0));
        elseif strcmp(name,'reset')
            at=sample==round(0.12/cfg.Ts);assert(all(trace(at,12:13)==0,'all') && all(trace(at,16)==0));
        end
        metric.status='passed';
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');
        if ~exist('metric','var') || ~strcmp(metric.name,name),metric=struct('name',name);end
        metric.status='failed';metric.error=record.error;
    end
    records.(name)=record;metrics{test}=metric;
    fprintf('%s\n',jsonencode(metric));
end
report=struct('release',version('-release'),'root',matlabroot,'kind','MIL physical PMSM axis only', ...
    'tests',numel(names),'passed',sum(cellfun(@(x)strcmp(x.status,'passed'),metrics)), ...
    'polarity_identified',false,'metrics',{metrics});
save(fullfile(module,'waveform_analysis','axis_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','axis_metrics.json'),'w');
fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
assert(report.passed==report.tests,'Some HFI MIL checks failed; inspect recorded traces.');
end
