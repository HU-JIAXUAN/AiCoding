function report=run_hfi_probe_validation()
%RUN_HFI_PROBE_VALIDATION Physical MIL of measured saliency, without nominal L.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'),fullfile(lib,'永磁同步电机','parameter'));
model='HFISaliencyTest';load_system(fullfile(module,'src',[model,'.slx']));
modelCleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'nominal_locked','zero_axis','near_quadrature','opposite_polarity','negative_axis','rotated_excitation', ...
    'changed_inductance','resistance_doubled','cross_unknown','cross_known','free_saturation','moving_shaft', ...
    'round_1mH','round_1p2mH','round_adc','constant_offsets','adc_noise_12bit','coarse_adc', ...
    'half_actual_voltage','weak_actual_voltage','current_delay_unaligned','current_delay_aligned', ...
    'execution_delay','disable','reset','overcurrent','no_voltage'};
records=struct();metrics=cell(size(names));
for test=1:numel(names)
    name=names{test};cfg=hfi_probe_parameters();fixture=hfi_probe_test_parameters();fixture.MechanicalEnabled=0;
    switch name
        case 'zero_axis',fixture.InitialElectricalAngle=0;
        case 'near_quadrature',fixture.InitialElectricalAngle=1.5;
        case 'opposite_polarity',fixture.InitialElectricalAngle=.7+pi;
        case 'negative_axis',fixture.InitialElectricalAngle=-.9;
        case 'rotated_excitation',cfg.ProbeAxis=1.1;
        case {'cross_unknown','cross_known'}
            fixture.CrossInductance=.2e-3;
            if strcmp(name,'cross_known'),cfg.CrossPhase=atan2(-2*fixture.CrossInductance,1.5e-3-1e-3);end
        case 'free_saturation',fixture.MechanicalEnabled=1;fixture.SaturationDepth=.25;
        case 'moving_shaft',fixture.MechanicalEnabled=1;
        case {'adc_noise_12bit','round_adc'}
            fixture.MeasurementNoise=.001;fixture.CurrentResolution=16/4096;
        case 'constant_offsets',fixture.CurrentOffset=[.03;-.02;.01];
        case 'coarse_adc',fixture.CurrentResolution=1;
        case 'half_actual_voltage',fixture.ActuationGain=.5;
        case 'weak_actual_voltage',fixture.ActuationGain=.1;
        case 'no_voltage',fixture.ActuationGain=0;
        case 'current_delay_unaligned',fixture.CurrentDelay=1;
        case 'current_delay_aligned',fixture.CurrentDelay=1;fixture.VoltageAlignmentDelay=1;
        case 'execution_delay',fixture.ExecutionDelay=1;
        case 'overcurrent',fixture.CurrentOffset=[4;0;0];
    end
    cfg=refresh_hfi_probe_parameters(cfg);motor=hfi_plant_parameters(fixture);
    switch name
        case {'round_1mH','round_adc'},motor.Lq=motor.Ld;
        case 'round_1p2mH',motor.Ld=.0012;motor.Lq=motor.Ld;
        case 'changed_inductance',motor.Ld=.0008;motor.Lq=.0018;
        case 'resistance_doubled',motor.Rs=2*motor.Rs;
        case 'moving_shaft'
            motor.Speed0=5/motor.PolePairs;
            fixture.LoadTorque=-motor.B*motor.Speed0-1.5*motor.PolePairs^2*motor.Flux^2*motor.Speed0/motor.Rs;
    end
    motor=refresh_pmsm_hf_parameters(motor);stimulus=hfi_stimulus(fixture);time=stimulus.time;sample=round(time/cfg.Ts);
    event=@(seconds)sample>=round(seconds/cfg.Ts);
    if strcmp(name,'disable'),stimulus.signals.values(event(.004)&~event(.010),3)=0;end
    if strcmp(name,'reset'),stimulus.signals.values(sample==round(.006/cfg.Ts),4)=1;end
    values=struct('probeCfg',cfg,'hfiTestCfg',fixture,'hfPlantCfg',motor,'testStim',stimulus);
    input=Simulink.SimulationInput(model);fields=fieldnames(values);
    for k=1:numel(fields),input=input.setVariable(fields{k},values.(fields{k}),'Workspace',model);end
    input=input.setModelParameter('StopTime',num2str(fixture.Duration,16));
    record=struct('name',name,'parameters',values);fprintf('HFI probe running %s\n',name);
    try
        timer=tic;output=sim(input);record.wall_time_s=toc(timer);y=output.trace.signals.values;
        record.time=output.trace.time;record.trace=y;
        assert(size(y,2)==38 && all(isfinite(y),'all') && max(abs(record.time-time))<1e-11);
        first=find(y(:,15)>.5,1);assert(~isempty(first),'Probe did not finish.');
        qualified=y(end,14)>.5;axisError=NaN;fullError=NaN;
        if qualified
            axisError=y(first,26);fullError=atan2(sin(y(first,12)-y(first,5)),cos(y(first,12)-y(first,5)));
        end
        linearChecked=motor.MechanicalEnabled==0 && motor.SaturationDepth==0;
        tensorError=NaN;
        if linearChecked
            theta=motor.Position0*motor.PolePairs;rotation=[cos(theta),-sin(theta);sin(theta),cos(theta)];
            expected=rotation/([motor.Ld,motor.CrossInductance;motor.CrossInductance,motor.Lq])*rotation';
            measured=[y(first,17),y(first,18);y(first,18),y(first,19)];
            tensorError=norm(measured-expected,'fro')/norm(expected,'fro');
        end
        metric=struct('name',name,'qualified',qualified,'quality_code',y(end,25),'fault_code',y(end,22), ...
            'saliency_ratio',y(end,13),'inverse_average_Hinv',y(end,16),'fit_residual',y(end,20), ...
            'axis_error_at_done_rad',axisError,'full_error_at_done_rad',fullError,'completion_time_s',time(first), ...
            'capture_samples',y(end,21),'linear_reference_checked',linearChecked,'tensor_relative_error',tensorError, ...
            'max_physical_current_A',max(hypot(y(:,37),y(:,38))), ...
            'max_rotor_movement_rad',max(abs(unwrap(y(:,5))-y(1,5))),'cross_phase_prior_rad',cfg.CrossPhase, ...
            'polarity_identified',false,'status','observed');
        bad={'round_1mH','round_1p2mH','round_adc','coarse_adc','weak_actual_voltage','current_delay_unaligned','overcurrent','no_voltage'};
        if ismember(name,bad)
            assert(~qualified && metric.quality_code~=1);
            if strcmp(name,'overcurrent'),assert(metric.fault_code==1);end
        else
            assert(qualified && metric.capture_samples==cfg.CaptureSamples);
            if strcmp(name,'cross_unknown'),assert(abs(axisError)>.2);
            elseif strcmp(name,'moving_shaft'),assert(abs(axisError)<.12 && abs(y(first,6))>2);
            else,assert(abs(axisError)<.03);
            end
            if linearChecked,assert(tensorError<.025);end
            if strcmp(name,'opposite_polarity'),assert(abs(fullError)>3);end
        end
        hold=time>=time(first) & stimulus.signals.values(:,3)>.5 & stimulus.signals.values(:,4)<.5;
        assert(all(y(hold,10:11)==0,'all'),'A completed/faulted probe must stop injection.');
        if strcmp(name,'disable')
            off=event(.004)&~event(.010);assert(all(y(off,[10,11,14,15])==0,'all'));
        elseif strcmp(name,'reset')
            at=sample==round(.006/cfg.Ts);assert(all(y(at,[10,11,14,15])==0,'all'));
        end
        metric.status='passed';
    catch exception
        record.error=getReport(exception,'extended','hyperlinks','off');
        if ~exist('metric','var') || ~strcmp(metric.name,name),metric=struct('name',name);end
        metric.status='failed';metric.error=record.error;
    end
    records.(name)=record;metrics{test}=metric;fprintf('%s\n',jsonencode(metric));
end
report=struct('release',version('-release'),'root',matlabroot,'kind','MIL physical saliency snapshot', ...
    'tests',numel(names),'passed',sum(cellfun(@(x)strcmp(x.status,'passed'),metrics)), ...
    'nominal_inductance_used_for_tensor_fit',false,'polarity_identified',false,'metrics',{metrics});
save(fullfile(module,'waveform_analysis','probe_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','probe_metrics.json'),'w');fwrite(file,jsonencode(report,PrettyPrint=true));fclose(file);
assert(report.tests==report.passed,'Some probe expectations failed; inspect saved traces.');
end
