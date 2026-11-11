function report=run_sigmoid_smo_validation()
%RUN_SIGMOID_SMO_VALIDATION Independent continuous-SPMSM MIL of smooth injection.
assert(strcmp(version('-release'),'2026b'));module=initialize_sigmoid_smo_paths();
model='SigmoidSlidingModeObserverTest';before=find_system('type','block_diagram');cleanup=onCleanup(@()close_added(before));
base=sigmoid_smo_parameters();test=sigmoid_smo_test_parameters();pll=sigmoid_smo_pll_parameters(base);
t=(0:base.Ts:test.Duration)';
names={'positive','negative','high_positive','high_negative','acceleration','measurement_noise_5mA','noise_10mA_qualification_drop', ...
    'rs_mismatch','l_mismatch','reset','disable','direction_unknown','direction_wrong','zero_speed','low_emf', ...
    'reversal','over_speed','current_range','current_nonfinite','voltage_nonfinite','direction_illegal','settings_invalid'};
records=struct();metrics=cell(numel(names),1);
normal={'positive','negative','high_positive','high_negative','acceleration','measurement_noise_5mA','rs_mismatch','l_mismatch','reset','disable','reversal'};
for n=1:numel(names)
    name=names{n};cfg=base;omega=test.Omega*ones(size(t));
    switch name
        case 'negative',omega=-omega;
        case 'high_positive',omega=test.HighOmega*ones(size(t));
        case 'high_negative',omega=-test.HighOmega*ones(size(t));
        case 'acceleration',omega=test.AccelerationStartOmega+min(t,test.AccelerationEnd)*test.Acceleration;
        case 'rs_mismatch',cfg.Rs=test.ResistanceScale*base.Rs;cfg=refresh_sigmoid_smo_parameters(cfg);
        case 'l_mismatch',cfg.L=test.InductanceScale*base.L;cfg=refresh_sigmoid_smo_parameters(cfg);
        case 'zero_speed',omega(:)=0;
        case 'low_emf',omega(:)=test.LowOmega;
        case 'over_speed',omega(:)=test.OverOmega;
        case 'reversal',omega=test.ReversalOmega*(1-2*min(max((t-test.ReversalStart)/test.ReversalDuration,0),1));
    end
    [stim,truth]=smo_fixture(t,omega,test.InitialTheta,test.Iq,base);
    switch name
        case {'measurement_noise_5mA','noise_10mA_qualification_drop'}
            rng(test.Seed);stim.signals.values(:,1:2)=stim.signals.values(:,1:2)+test.VoltageNoiseStd*randn(numel(t),2);
            noise=test.CurrentNoiseStd;if strcmp(name,'noise_10mA_qualification_drop'),noise=test.HighCurrentNoiseStd;end
            stim.signals.values(:,3:4)=stim.signals.values(:,3:4)+noise*randn(numel(t),2);
        case 'reset',stim.signals.values(t>=test.ResetStart & t<test.ResetStart+test.ResetDuration,7)=1;
        case 'disable',stim.signals.values(t>=test.DisableStart & t<test.DisableEnd,6)=0;
        case 'direction_unknown',stim.signals.values(:,5)=0;
        case 'direction_wrong',stim.signals.values(:,5)=-1;
        case {'zero_speed','low_emf'},stim.signals.values(:,5)=1;
        case 'current_range',stim.signals.values(t>=test.FaultStart,3)=base.MaxCurrent+test.FaultCurrentExcess;
        case 'current_nonfinite',stim.signals.values(t>=test.FaultStart & t<test.FaultStart+test.FaultDuration,3)=NaN;
        case 'voltage_nonfinite',stim.signals.values(t>=test.FaultStart & t<test.FaultStart+test.FaultDuration,1)=Inf;
        case 'direction_illegal',stim.signals.values(:,5)=2;
        case 'settings_invalid',cfg.Settings(3)=-1;
    end
    in=Simulink.SimulationInput(model);in=in.setVariable('sigmoidCfg',cfg,'Workspace',model);
    in=in.setVariable('pllCfg',pll,'Workspace',model);in=in.setVariable('testStim',stim,'Workspace',model);
    in=in.setModelParameter('StopTime',num2str(t(end),16),'SignalInfNanChecking','none');out=sim(in);
    v=out.trace.signals.values;time=out.trace.time;assert(size(v,2)==24 && all(isfinite(v(:,10:24)),'all'));
    assert(isequaln(v(:,1:9),stim.signals.values),'Logged stimulus must equal supplied input.');
    assert(max(abs(v(:,13:14)),[],'all')<=base.SlidingGain+1e-9);
    q=time>=test.WindowStart;speedError=v(:,11)-v(:,9);
    metric=struct('name',name,'angle_rms_rad',sqrt(mean(v(q,24).^2)),'angle_max_rad',max(abs(v(q,24))), ...
        'speed_rms_rad_s',sqrt(mean(speedError(q).^2)),'valid_fraction',mean(v(q,12)), ...
        'maximum_residual_A',max(v(q,23)),'fault',max(v(:,22)),'window_start_s',test.WindowStart, ...
        'window_end_s',test.Duration,'passed',false);
    if ismember(name,normal)
        assert(metric.angle_max_rad<test.MaximumAngleError && metric.speed_rms_rad_s<test.MaximumSpeedRms, ...
            '%s tracking failed: angle %.6g, speed %.6g.',name,metric.angle_max_rad,metric.speed_rms_rad_s);
        assert(metric.valid_fraction>test.MinimumValidFraction,'%s failed qualification.',name);
    elseif strcmp(name,'noise_10mA_qualification_drop')
        % Preserve the original failure as a limitation, without weakening qualification.
        assert(metric.valid_fraction<test.MinimumValidFraction && metric.angle_max_rad<test.MaximumAngleError && metric.fault==0);
    else
        assert(all(v(q,12)==0),'%s must not publish a qualified position in the final window.',name);
    end
    if ismember(name,{'reset','disable'})
        inactive=v(:,6)<.5 | v(:,7)>.5;
        assert(all(v(inactive,12)==0) && all(v(inactive,13:18)==0,'all'));
    elseif ismember(name,{'current_range','current_nonfinite','voltage_nonfinite'})
        after=time>=test.FaultStart+test.FaultVerifyDelay;assert(all(v(after,22)==1) && all(v(after,12)==0));
    elseif ismember(name,{'direction_illegal','settings_invalid'})
        assert(all(v(:,22)==2));
    end
    metric.passed=true;metrics{n}=metric;
    records.(name)=struct('model',model,'configuration',cfg,'pll',pll,'inputs',stim.signals.values, ...
        'truth',truth,'time',time,'trace',v,'metrics',metric);
    file=fopen(fullfile(module,'waveform_analysis','sigmoid_progress.json'),'w');
    fprintf(file,'%s',jsonencode(struct('completed',n,'total',numel(names),'last_case',name)));fclose(file);
end
metrics=vertcat(metrics{:});
in=Simulink.SimulationInput(model);in=in.setVariable('sigmoidCfg',base,'Workspace',model);
in=in.setVariable('pllCfg',pll,'Workspace',model);
[stim,~]=smo_fixture(t,test.Omega*ones(size(t)),test.InitialTheta,test.Iq,base);
in=in.setVariable('testStim',stim,'Workspace',model);out=sim(in);
repeatDifference=max(abs(out.trace.signals.values-records.positive.trace),[],'all');assert(repeatDifference==0);
report=struct('status','passed','matlab_version',version,'release',version('-release'),'tests',numel(names), ...
    'tracking_cases',numel(normal),'rejection_cases',numel(names)-numel(normal)-1,'noise_limitation_cases',1, ...
    'passed',sum([metrics.passed]),'repeat_default_difference',repeatDifference,'metrics',metrics, ...
    'columns',{{'u_alpha','u_beta','i_alpha','i_beta','direction','enable','reset','theta_true','omega_true', ...
    'theta_hat','omega_hat','valid','emf_alpha','emf_beta','i_hat_alpha','i_hat_beta','residual_alpha','residual_beta', ...
    'phase_measured','emf_magnitude','phase_error','fault','residual_norm','angle_error'}});
save(fullfile(module,'waveform_analysis','sigmoid_results.mat'),'records','report');
file=fopen(fullfile(module,'waveform_analysis','sigmoid_metrics.json'),'w','n','UTF-8');
fprintf(file,'%s',jsonencode(report,'PrettyPrint',true));fclose(file);
disp(struct2table(metrics));clear cleanup;
end
function close_added(before)
after=find_system('type','block_diagram');
for k=1:numel(after),if ~ismember(after{k},before),close_system(after{k},0);end,end
end
