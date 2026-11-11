function report=compare_ekf_ukf(referenceResults)
%COMPARE_EKF_UKF Compare saved identical-input MIL data, not MCU runtime.
folder=fileparts(mfilename('fullpath'));lib=fileparts(fileparts(fileparts(folder)));
if nargin<1,referenceResults=fullfile(lib,'观测器','扩展卡尔曼','waveform_analysis','results.mat');end
u=load(fullfile(folder,'results.mat'),'records');e=load(referenceResults,'records');
names=fieldnames(e.records);metrics=struct([]);
for k=1:numel(names)
    name=names{k};assert(isfield(u.records,name));a=e.records.(name);b=u.records.(name);
    assert(isequaln(a.stimulus.signals.values,b.stimulus.signals.values)&&isequal(a.time,b.time));
    assert(isequal(a.configuration.Settings,b.configuration.Settings));
    entry=struct('name',name,'identical_inputs_and_common_parameters',true, ...
        'EKF_angle_rms_rad',a.metric.angle_rms_rad,'UKF_angle_rms_rad',b.metric.angle_rms_rad, ...
        'EKF_speed_rms_rad_s',a.metric.speed_rms_rad_s,'UKF_speed_rms_rad_s',b.metric.speed_rms_rad_s, ...
        'EKF_valid_fraction',a.metric.valid_fraction,'UKF_valid_fraction',b.metric.valid_fraction);
    if isempty(metrics),metrics=entry;else,metrics(end+1)=entry;end %#ok<AGROW>
end
assert(numel(metrics)==25);
cost=struct('normal_active_EKF_process_evaluations',1,'normal_active_UKF_process_evaluations',9, ...
    'normal_active_EKF_covariance_cholesky_calls',0,'normal_active_UKF_covariance_cholesky_calls',2, ...
    'maximum_UKF_cholesky_attempts_including_jitter',12, ...
    'source','EKF Jacobian propagation vs UKF point propagation and two bounded full covariance checks', ...
    'target_execution_time','NOT_MEASURED','target_memory','NOT_MEASURED', ...
    'host_runtime_note','Separate MIL execution_wall_s values are not a controlled timing benchmark and are not ranked here.');
report=struct('status','passed','release',version('-release'),'matching_cases',numel(metrics), ...
    'metrics',metrics,'cost_evidence',cost,'conclusion','Comparable steady errors in these trajectories; no general superiority claim.');
save(fullfile(folder,'comparison_results.mat'),'report','-v7.3');
fid=fopen(fullfile(folder,'comparison_metrics.json'),'w');fwrite(fid,jsonencode(report,PrettyPrint=true));fclose(fid);
fig=figure('Visible','off','Color','w','Position',[50,50,1280,900]);guard=onCleanup(@()close(fig)); %#ok<NASGU>
tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
nexttile;plot(e.records.positive.time*1e3,e.records.positive.trace(:,50),'LineWidth',1);hold on;
plot(u.records.positive.time*1e3,u.records.positive.trace(:,50),'--','LineWidth',1);xlim([0,40]);grid on;
xlabel('Time (ms)');ylabel('Wrapped angle error (rad)');title('Default initial capture');legend('EKF','UKF','Location','best');
nexttile;a=e.records.speed_ramp;b=u.records.speed_ramp;
plot(a.time,a.trace(:,11)-a.truth.omega,'LineWidth',1);hold on;plot(b.time,b.trace(:,11)-b.truth.omega,'--','LineWidth',1);
xlim([.08,b.time(end)]);grid on;xlabel('Time (s)');ylabel('Electrical speed error (rad/s)');title('Same accelerating trajectory');legend('EKF','UKF','Location','best');
nexttile;selected={'positive','speed_ramp','rs_mismatch','L_mismatch','adc_noise'};values=zeros(numel(selected),2);
for k=1:numel(selected),values(k,:)=[e.records.(selected{k}).metric.angle_rms_rad,u.records.(selected{k}).metric.angle_rms_rad];end
bar(values);grid on;xticks(1:numel(selected));xticklabels({'Default','Ramp','Rs +20%','L +20%','ADC noise'});xtickangle(15);
ylabel('Window angle RMS (rad)');title('Saved-case comparison');legend('EKF','UKF','Location','best');
nexttile;selected={'positive','sigma_alpha_small','sigma_kappa_two'};
for k=1:numel(selected),b=u.records.(selected{k});plot(b.time*1e3,b.trace(:,22),'LineWidth',1);hold on;end
xlim([0,40]);grid on;xlabel('Time (ms)');ylabel('Continuous qualification (samples)');title('UT tuning changes early qualification');
legend('Alpha 1 / Kappa 0','Alpha 0.2 / Kappa 0','Alpha 1 / Kappa 2','Location','best');
sgtitle('Four-state SPMSM: matched process, measurements and covariance defaults');
exportgraphics(fig,fullfile(folder,'ukf_ekf_comparison.png'),'Resolution',160);
exportgraphics(fig,fullfile(folder,'ukf_ekf_comparison.svg'),'ContentType','vector');
end
