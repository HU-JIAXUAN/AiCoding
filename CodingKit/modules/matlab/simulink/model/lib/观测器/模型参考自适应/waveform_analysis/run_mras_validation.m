function report=run_mras_validation(selectedCases)
%RUN_MRAS_VALIDATION Independent continuous-equation MRAS fixtures and refusal.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'build_process'));
model='MrasObserverTest';load_system(fullfile(module,'src',[model,'.slx']));
cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'positive','negative','angle_negative','near_pi','speed_prior_high','low_speed', ...
    'speed_ramp','dq_transient','adc_noise','rs_mismatch','L_mismatch','flux_mismatch', ...
    'zero_speed','below_operating','unknown_direction','wrong_direction','disable_restart', ...
    'reset','reversal','invalid_direction','nonfinite_voltage','nonfinite_current','current_delay','repeat_default'};
planned=names;fullRun=nargin==0 || isempty(selectedCases);
if ~fullRun,selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));names=names(ismember(names,selectedCases));end
records=struct();criteria=mras_test_parameters();failureMessage='';
for number=1:numel(names)
    name=names{number};cfg=mras_parameters();motor=cfg;test=mras_test_parameters();
    switch name
        case 'negative',test.ElectricalSpeed=-600;test.Direction=-1;
        case 'angle_negative',test.InitialAngle=-1.5;
        case 'near_pi',test.InitialAngle=pi-.01;
        case 'speed_prior_high',cfg.InitialOmega=900;
        case 'low_speed',test.ElectricalSpeed=100;cfg.InitialOmega=100;
        case 'adc_noise',test.NoiseRms=.001;
        case 'speed_ramp',test.Duration=.6;test.CheckStart=.45;
        case 'rs_mismatch',cfg.Rs=1.2*cfg.Rs;test.Id=-1;
        case 'L_mismatch',cfg.L=1.2*cfg.L;
        case 'flux_mismatch',cfg.Flux=.9*cfg.Flux;
        case 'zero_speed',test.ElectricalSpeed=0;
        case 'below_operating',test.ElectricalSpeed=20;cfg.InitialOmega=20;
        case 'unknown_direction',test.Direction=0;
        case 'wrong_direction',test.Direction=-1;
        case {'disable_restart','reset'},test.Duration=.7;test.CheckStart=.55;
        case 'reversal',test.Duration=1;test.CheckStart=.85;
        case 'invalid_direction',test.Direction=2;
        case 'current_delay',test.CurrentDelay=1;
    end
    cfg=refresh_mras_parameters(cfg);t=(0:cfg.Ts:test.Duration).';
    omega=test.ElectricalSpeed*ones(size(t));id=test.Id*ones(size(t));iq=test.Iq*ones(size(t));direction=test.Direction;
    if strcmp(name,'speed_ramp'),omega=300+600*min(max((t-.1)/.25,0),1);end
    if strcmp(name,'dq_transient')
        id=-.5*(1+tanh((t-.15)/.01))/2;iq=2+(1+tanh((t-.2)/.01))/2;
    end
    if strcmp(name,'reversal')
        omega=600-1200*min(max((t-.15)/.5,0),1);
        direction=sign(omega);direction(abs(omega)<motor.MinOmega)=0;
    end
    [stimulus,truth]=mras_fixture(t,omega,test.InitialAngle,id,iq,motor,direction);
    switch name
        case 'adc_noise'
            stream=RandStream('mt19937ar','Seed',test.NoiseSeed);
            stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+test.NoiseRms*randn(stream,numel(t),2);
        case 'disable_restart',stimulus.signals.values(t>=.2 & t<.25,6)=0;
        case 'reset',stimulus.signals.values(round(t/cfg.Ts)==round(.2/cfg.Ts),7)=1;
        case 'nonfinite_voltage',stimulus.signals.values(t>=.25,1)=NaN;
        case 'nonfinite_current',stimulus.signals.values(t>=.25,3)=NaN;
        case 'current_delay',stimulus.signals.values(:,3:4)=[zeros(1,2);stimulus.signals.values(1:end-1,3:4)];
    end
    in=Simulink.SimulationInput(model);in=in.setVariable('mrasCfg',cfg,'Workspace',model);
    in=in.setVariable('mrasTestCfg',test,'Workspace',model);in=in.setVariable('testStim',stimulus,'Workspace',model);
    in=in.setModelParameter('StopTime',num2str(test.Duration,16));out=sim(in);
    trace=out.trace.signals.values;assert(isequal(size(trace),[numel(t),26]));
    assert(max(abs(out.trace.time-t))<1e-12);t=out.trace.time;
    assert(all(isfinite(trace(:,10:26)),'all'));y=trace(:,10:25);check=t>=test.CheckStart;
    error=atan2(sin(y(:,1)-truth.theta),cos(y(:,1)-truth.theta));
    assert(max(abs(error-trace(:,26)))<1e-12);
    first=find(y(:,3)>.5,1);capture=NaN;if ~isempty(first),capture=t(first);end
    metric=struct('name',name,'angle_rms_rad',sqrt(mean(error(check).^2)), ...
        'speed_rms_rad_s',sqrt(mean((y(check,2)-truth.omega(check)).^2)), ...
        'valid_fraction',mean(y(check,3)),'capture_s',capture,'maximum_fault',max(y(:,15)), ...
        'mean_emf_V',mean(y(check,12)),'mean_normalized_q',mean(y(check,11)), ...
        'execution_wall_s',out.SimulationMetadata.TimingInfo.ExecutionElapsedWallTime,'status','pending');
    record=struct('configuration',cfg,'test',test,'truth',truth,'stimulus',stimulus, ...
        'time',t,'trace',trace,'criteria',criteria,'metric',metric);records.(name)=record;
    try
        assert(max(abs(y(:,1)))<=pi+1e-12 && all(y(:,3)==0 | y(:,3)==1));
        assert(all(y(:,13)>=0 & y(:,13)<=cfg.QualificationSamples));
        assert(max(abs(y(:,2)))<=cfg.MaxOmega+1e-12 && max(abs(y(:,14)))<=cfg.MaxOmega+1e-12);
        fault=ismember(name,{'invalid_direction','nonfinite_voltage','nonfinite_current'});
        refused=ismember(name,{'zero_speed','below_operating','unknown_direction','wrong_direction'});
        if fault
            expected=1;if strcmp(name,'invalid_direction'),expected=2;end
            assert(all(y(check,3)==0) && all(y(check,15)==expected));
        elseif refused
            assert(~any(y(:,3)>.5) && ~any(y(:,15)>0));
            if strcmp(name,'zero_speed'),assert(mean(y(check,12))<cfg.MinEmf && mean(y(check,11))>.8);end
        else
            assert(~any(y(:,15)>0) && metric.valid_fraction>=criteria.ValidFractionMinimum);
            assert(metric.angle_rms_rad<criteria.AngleRmsLimit && metric.speed_rms_rad_s<criteria.SpeedRmsLimit);
            assert(max(abs(error(y(:,3)>.5)))<.2);
            if strcmp(name,'speed_ramp'),assert(all(y(t>=.12,3)>.5),'Qualification must remain active through acceleration.');end
            inactive=stimulus.signals.values(:,6)<.5 | stimulus.signals.values(:,7)>.5;
            assert(all(y(inactive,3)==0) && all(y(inactive,2)==0));
            if strcmp(name,'repeat_default') && isfield(records,'positive')
                assert(isequal(trace,records.positive.trace),'Instance state was not reinitialized.');
            end
        end
        metric.status='passed';
    catch exception
        metric.status='failed';failureMessage=exception.message;records.(name).metric=metric;
        save_results('failed');rethrow(exception);
    end
    records.(name).metric=metric;
end
report=save_results('passed');
    function report=save_results(status)
        savedNames=fieldnames(records);savedMetrics=struct([]);
        for savedIndex=1:numel(savedNames)
            item=records.(savedNames{savedIndex}).metric;
            if savedIndex==1,savedMetrics=item;else,savedMetrics(savedIndex)=item;end
        end
        report=struct('release',version('-release'),'matlabroot',matlabroot, ...
            'kind','independent continuous dq-balance input; no physical motor-drive closed loop', ...
            'status',status,'tests',numel(savedNames),'passed',sum(strcmp({savedMetrics.status},'passed')), ...
            'full_run',fullRun,'planned_cases',{planned},'criteria',criteria,'metrics',savedMetrics);
        if strcmp(status,'failed'),report.failed_case=names{number};report.failure_message=failureMessage;end
        stem='results';metricName='metrics';if ~fullRun,stem='subset_results';metricName='subset_metrics';end
        folder=fullfile(module,'waveform_analysis');save(fullfile(folder,[stem,'.mat']),'records','report','-v7.3');
        handle=fopen(fullfile(folder,[metricName,'.json']),'w');fwrite(handle,jsonencode(report,PrettyPrint=true));fclose(handle);
    end
end
