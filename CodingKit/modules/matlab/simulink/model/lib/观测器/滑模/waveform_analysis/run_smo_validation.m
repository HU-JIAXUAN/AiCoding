function report = run_smo_validation()
%RUN_SMO_VALIDATION Verify a boundary-layer SMO against analytic SPMSM signals.
assert(strcmp(version('-release'),'2026b'));
module=fileparts(fileparts(mfilename('fullpath')));pllModule=fullfile(fileparts(fileparts(module)),'相位跟踪');
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'), ...
    fullfile(pllModule,'parameter'),fullfile(pllModule,'src'));
open_system(fullfile(module,'src','SlidingModeObserverTest.slx'));
base=smo_parameters();pllCfg=angle_tracking_parameters();pllCfg.MinMagnitude=base.MinEmf;
t=(0:base.Ts:0.3)';
names={'positive','negative','high_positive','high_negative','acceleration','measurement_noise', ...
    'rs_mismatch','without_compensation','reset','disable','direction_invalid','reversal', ...
    'zero_speed','low_emf'};
records=struct();metrics=struct([]);
for n=1:numel(names)
    name=names{n};smoCfg=base;omega=200*ones(size(t));
    switch name
        case 'negative',omega=-omega;
        case 'high_positive',omega=600*ones(size(t));
        case 'high_negative',omega=-600*ones(size(t));
        case 'acceleration',omega=100+min(t,0.2)*2000;
        case 'rs_mismatch',smoCfg.Rs=base.Rs*1.2;smoCfg=refresh_smo_parameters(smoCfg);
        case 'without_compensation',smoCfg.Compensate=0;
        case 'reversal',omega=300-600*min(max((t-0.10)/0.10,0),1);
        case 'zero_speed',omega=zeros(size(t));
        case 'low_emf',omega=5*ones(size(t));
    end
    [stim,truth]=smo_fixture(t,omega,0.4,2,base);
    if strcmp(name,'measurement_noise')
        rng(23);stim.signals.values(:,1:2)=stim.signals.values(:,1:2)+0.02*randn(numel(t),2);
        stim.signals.values(:,3:4)=stim.signals.values(:,3:4)+0.01*randn(numel(t),2);
    elseif strcmp(name,'reset')
        stim.signals.values(t>=0.15 & t<0.1501,7)=1;
    elseif strcmp(name,'disable')
        stim.signals.values(t>=0.10 & t<0.15,6)=0;
    elseif strcmp(name,'direction_invalid')
        stim.signals.values(:,5)=0;
    elseif ismember(name,{'zero_speed','low_emf'})
        stim.signals.values(:,5)=1; % Known startup direction; EMF must still fail qualification.
    end
    in=Simulink.SimulationInput('SlidingModeObserverTest');
    in=in.setVariable('smoCfg',smoCfg,'Workspace','SlidingModeObserverTest');
    in=in.setVariable('pllCfg',pllCfg,'Workspace','SlidingModeObserverTest');
    in=in.setVariable('testStim',stim,'Workspace','SlidingModeObserverTest');
    in=in.setModelParameter('StopTime',num2str(t(end),16));out=sim(in);
    v=out.trace.signals.values;time=out.trace.time;
    assert(size(v,2)==22 && all(isfinite(v),'all'));
    assert(max(abs(v(:,17:18)),[],'all')<=smoCfg.SlidingGain+1e-9);
    idx=time>=0.25;angleError=v(:,22);speedError=v(:,11)-v(:,9);
    m=struct('name',name,'angle_rms_rad',sqrt(mean(angleError(idx).^2)), ...
        'angle_max_rad',max(abs(angleError(idx))),'speed_rms_rad_s',sqrt(mean(speedError(idx).^2)), ...
        'valid_fraction',mean(v(idx,12)),'window_start_s',0.25,'window_end_s',0.3,'passed',false);
    if ~ismember(name,{'direction_invalid','zero_speed','low_emf'})
        if strcmp(name,'without_compensation'),limit=0.15;else,limit=0.08;end
        assert(m.angle_max_rad<limit && m.speed_rms_rad_s<15,'%s: tracking tolerance exceeded.',name);
        assert(m.valid_fraction>0.95,'%s: observer did not qualify.',name);
    else
        assert(all(v(idx,12)==0),'Invalid direction or low EMF must not qualify.');
    end
    if ismember(name,{'reset','disable'})
        q=v(:,6)<0.5 | v(:,7)>0.5;
        assert(all(v(q,12)==0) && all(v(q,13:18)==0,'all'));
    elseif strcmp(name,'reversal')
        q=v(:,5)==0;assert(all(v(q,12)==0));
    end
    m.passed=true;
    if n==1,metrics=m;else,metrics(n)=m;end
    records.(name)=struct('model','SlidingModeObserverTest','configuration',smoCfg,'pll',pllCfg, ...
        'inputs',stim.signals.values,'truth',truth,'time',time,'trace',v,'metrics',m);
end
assert(records.positive.metrics.angle_rms_rad < records.without_compensation.metrics.angle_rms_rad, ...
    'Discrete LPF phase compensation did not improve the nominal fixture.');
channels={'u_alpha','u_beta','i_alpha','i_beta','direction','enable','reset','theta_true','omega_true', ...
    'theta_e_hat','omega_e_hat','valid','emf_alpha','emf_beta','i_hat_alpha','i_hat_beta', ...
    'injection_alpha','injection_beta','phase_measured','emf_magnitude','phase_error','angle_error'};
report=struct('matlab_version',version,'release',version('-release'),'tests',numel(names), ...
    'passed',sum([metrics.passed]),'metrics',metrics,'channels',{channels});
folder=fullfile(module,'waveform_analysis');save(fullfile(folder,'results.mat'),'records','report');
fid=fopen(fullfile(folder,'metrics.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
export_smo_plots(folder);
disp(struct2table(metrics));
end
