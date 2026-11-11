function report=run_ukf_validation(selectedCases)
%RUN_UKF_VALIDATION Independent input trajectories and full covariance checks.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(module,'build_process'));initialize_ukf_paths();
model='UkfObserverTest';load_system(fullfile(module,'src',[model,'.slx']));
cleanup=onCleanup(@()close_system(model,0)); %#ok<NASGU>
names={'positive','negative','angle_negative','near_pi','speed_prior_high','low_speed','speed_ramp','dq_transient', ...
    'adc_noise','rs_mismatch','L_mismatch','flux_mismatch','zero_speed','below_operating','unknown_direction', ...
    'wrong_direction','disable_restart','reset','reversal','invalid_direction','nonfinite_voltage', ...
    'nonfinite_current','current_delay','half_sample_time','sigma_alpha_small','sigma_kappa_two', ...
    'sigma_angle_range','invalid_sigma_alpha','repeat_default'};
planned=names;fullRun=nargin==0 || isempty(selectedCases);
if ~fullRun,selectedCases=cellstr(selectedCases);assert(all(ismember(selectedCases,names)));names=names(ismember(names,selectedCases));end
records=struct();criteria=ukf_test_parameters();failureMessage='';
for number=1:numel(names)
    name=names{number};cfg=ukf_parameters();motor=cfg.Model;test=ukf_test_parameters();
    switch name
        case 'negative',test.ElectricalSpeed=-600;test.Direction=-1;
        case 'angle_negative',test.InitialAngle=-1.5;
        case 'near_pi',test.InitialAngle=pi-.01;
        case 'speed_prior_high',cfg.InitialOmega=900;
        case 'low_speed',test.ElectricalSpeed=100;cfg.InitialOmega=100;
        case 'speed_ramp',test.Duration=.6;test.CheckStart=.45;
        case 'adc_noise',test.NoiseRms=.001;
        case 'rs_mismatch',cfg.Model.Rs=1.2*cfg.Model.Rs;test.Id=-1;
        case 'L_mismatch',cfg.Model.L=1.2*cfg.Model.L;
        case 'flux_mismatch',cfg.Model.Flux=.9*cfg.Model.Flux;
        case 'zero_speed',test.ElectricalSpeed=0;
        case 'below_operating',test.ElectricalSpeed=20;cfg.InitialOmega=20;
        case 'unknown_direction',test.Direction=0;
        case 'wrong_direction',test.Direction=-1;
        case {'disable_restart','reset'},test.Duration=.7;test.CheckStart=.55;
        case 'reversal',test.Duration=1;test.CheckStart=.85;
        case 'invalid_direction',test.Direction=2;
        case 'current_delay',test.CurrentDelay=1;
        case 'half_sample_time',cfg.Model.Ts=cfg.Model.Ts/2;
        case 'sigma_alpha_small',cfg.Alpha=.2;
        case 'sigma_kappa_two',cfg.Kappa=2;
        case 'sigma_angle_range',cfg.InitialStd(4)=1;
    end
    cfg=refresh_ukf_parameters(cfg);
    if strcmp(name,'invalid_sigma_alpha'),cfg.UnscentedSettings(28)=.01;end % Deliberate packed-parameter corruption.
    motor.Ts=cfg.Model.Ts;t=(0:motor.Ts:test.Duration).';
    omega=test.ElectricalSpeed*ones(size(t));id=test.Id*ones(size(t));iq=test.Iq*ones(size(t));direction=test.Direction;
    if strcmp(name,'speed_ramp'),omega=300+600*min(max((t-.1)/.25,0),1);end
    if strcmp(name,'dq_transient'),id=-.5*(1+tanh((t-.15)/.01))/2;iq=2+(1+tanh((t-.2)/.01))/2;end
    if strcmp(name,'reversal')
        omega=600-1200*min(max((t-.15)/.5,0),1);direction=sign(omega);direction(abs(omega)<30)=0;
    end
    [stimulus,truth]=spmsm_estimation_fixture(t,omega,test.InitialAngle,id,iq,motor,direction);
    if test.NoiseRms>0
        stream=RandStream('mt19937ar','Seed',test.NoiseSeed);
        stimulus.signals.values(:,3:4)=stimulus.signals.values(:,3:4)+test.NoiseRms*randn(stream,numel(t),2);
    end
    if test.CurrentDelay>0,stimulus.signals.values(:,3:4)=[zeros(1,2);stimulus.signals.values(1:end-1,3:4)];end
    switch name
        case 'disable_restart',stimulus.signals.values(t>=.2 & t<.25,6)=0;
        case 'reset',stimulus.signals.values(round(t/motor.Ts)==round(.2/motor.Ts),7)=1;
        case 'nonfinite_voltage',stimulus.signals.values(t>=.25,1)=NaN;
        case 'nonfinite_current',stimulus.signals.values(t>=.25,3)=NaN;
    end
    in=Simulink.SimulationInput(model);in=in.setVariable('ukfCfg',cfg,'Workspace',model);
    in=in.setVariable('ukfTestCfg',test,'Workspace',model);in=in.setVariable('testStim',stimulus,'Workspace',model);
    in=in.setModelParameter('StopTime',num2str(test.Duration,16));out=sim(in);
    log=out.trace;trace=log_matrix(log,50);assert(numel(log.time)==numel(t) && max(abs(log.time-t))<1e-12);t=log.time;
    assert(all(isfinite(trace(:,10:50)),'all'));y=trace(:,10:33);check=t>=test.CheckStart;
    error=atan2(sin(y(:,1)-truth.theta),cos(y(:,1)-truth.theta));assert(max(abs(error-trace(:,50)))<1e-12);
    first=find(y(:,3)>.5,1);capture=NaN;if ~isempty(first),capture=t(first);end
    covarianceChecks=check_covariances(trace(:,34:49),y);
    metric=struct('name',name,'angle_rms_rad',sqrt(mean(error(check).^2)), ...
        'speed_rms_rad_s',sqrt(mean((y(check,2)-truth.omega(check)).^2)), ...
        'valid_fraction',mean(y(check,3)),'capture_s',capture,'maximum_fault',max(y(:,14)), ...
        'mean_NIS',mean(y(check,8)),'mean_theta_std_rad',mean(y(check,9)), ...
        'mean_rate_mismatch_rad_s',mean(y(check,12)), ...
        'maximum_covariance_symmetry_error',covarianceChecks.maximum_symmetry_error, ...
        'minimum_normalized_covariance_pivot',covarianceChecks.minimum_pivot, ...
        'maximum_numeric_repairs',max(y(:,24)), ...
        'execution_wall_s',out.SimulationMetadata.TimingInfo.ExecutionElapsedWallTime,'status','pending');
    records.(name)=struct('configuration',cfg,'test',test,'truth',truth,'stimulus',stimulus, ...
        'time',t,'trace',trace,'raw_log_shape',size(log.signals.values),'criteria',criteria,'metric',metric);
    try
        assert(max(abs(y(:,1)))<=pi+1e-12 && all(y(:,3)==0 | y(:,3)==1));
        assert(all(y(:,13)>=0 & y(:,13)<=cfg.QualificationSamples));
        assert(all(y(:,24)>=0 & y(:,24)==floor(y(:,24))));
        assert(all(y(:,24)==0),'No numerical repairs are expected in these normal double MIL trajectories.');
        fault=ismember(name,{'invalid_direction','nonfinite_voltage','nonfinite_current','sigma_angle_range','invalid_sigma_alpha'});
        refused=ismember(name,{'flux_mismatch','zero_speed','below_operating','unknown_direction','wrong_direction'});
        if fault
            expected=1;if ismember(name,{'invalid_direction','invalid_sigma_alpha'}),expected=2;end
            if strcmp(name,'sigma_angle_range'),expected=3;end
            assert(all(y(check,3)==0) && all(y(check,14)==expected));
        elseif refused
            assert(~any(y(:,3)>.5) && ~any(y(:,14)>0));
            if strcmp(name,'flux_mismatch'),assert(mean(y(check,8))>cfg.MaxNIS);end
        else
            assert(~any(y(:,14)>0) && metric.valid_fraction>=criteria.ValidFractionMinimum);
            assert(metric.angle_rms_rad<criteria.AngleRmsLimit && metric.speed_rms_rad_s<criteria.SpeedRmsLimit);
            assert(max(abs(error(y(:,3)>.5)))<.2);
            if strcmp(name,'speed_ramp'),assert(all(y(t>=.12,3)>.5));end
            inactive=stimulus.signals.values(:,6)<.5 | stimulus.signals.values(:,7)>.5;
            assert(all(y(inactive,3)==0) && all(y(inactive,2)==0));
            if strcmp(name,'repeat_default') && isfield(records,'positive'),assert(isequal(trace,records.positive.trace));end
        end
        metric.status='passed';
    catch exception
        metric.status='failed';failureMessage=exception.message;records.(name).metric=metric;save_results('failed');rethrow(exception);
    end
    records.(name).metric=metric;
end
report=save_results('passed');
    function report=save_results(status)
        fields=fieldnames(records);metrics=struct([]);
        for k=1:numel(fields),entry=records.(fields{k}).metric;if k==1,metrics=entry;else,metrics(k)=entry;end,end
        report=struct('release',version('-release'),'matlabroot',matlabroot,'status',status, ...
            'kind','independent continuous SPMSM dq-balance input; no physical drive closed loop', ...
            'tests',numel(fields),'passed',sum(strcmp({metrics.status},'passed')),'full_run',fullRun, ...
            'planned_cases',{planned},'criteria',criteria,'metrics',metrics);
        if strcmp(status,'failed'),report.failed_case=names{number};report.failure_message=failureMessage;end
        stem='results';metricFile='metrics';if ~fullRun,stem='subset_results';metricFile='subset_metrics';end
        folder=fullfile(module,'waveform_analysis');save(fullfile(folder,[stem,'.mat']),'records','report','-v7.3');
        handle=fopen(fullfile(folder,[metricFile,'.json']),'w');fwrite(handle,jsonencode(report,PrettyPrint=true));fclose(handle);
    end
end
function matrix=log_matrix(log,width)
raw=log.signals.values;n=numel(log.time);
if size(raw,1)==n,matrix=reshape(raw,n,[]);
elseif size(raw,ndims(raw))==n,matrix=reshape(raw,[],n).';
else,error('UKF:LogShape','The time dimension could not be identified.');end
assert(isequal(size(matrix),[n,width]));
end
function report=check_covariances(values,outputs)
scales=[1;1;100;1];normalizer=scales*scales';symmetry=0;minimum=Inf;
for k=1:size(values,1)
    p=reshape(values(k,:),4,4);scaled=p./normalizer;
    symmetry=max(symmetry,max(abs(scaled-scaled'),[],'all'));
    assert(max(abs(diag(p)-outputs(k,15:18).'))<1e-10);
    [factor,flag]=chol(scaled,'lower');assert(flag==0,'Posterior covariance must remain positive definite.');
    minimum=min(minimum,min(diag(factor)));
end
assert(symmetry<1e-12);
report=struct('maximum_symmetry_error',symmetry,'minimum_pivot',minimum);
end
