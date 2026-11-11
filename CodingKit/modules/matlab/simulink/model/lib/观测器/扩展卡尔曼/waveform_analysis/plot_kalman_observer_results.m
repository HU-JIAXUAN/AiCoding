function plot_kalman_observer_results(folder,label,stem)
%PLOT_KALMAN_OBSERVER_RESULTS Shared plots for the same EKF/UKF trace contract.
data=load(fullfile(folder,'results.mat'),'records');r=data.records.positive;t=r.time;a=r.trace;
h=figure('Visible','off','Position',[100,100,1150,1400]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(6,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t,a(:,[9,11,20]));grid on;ylabel('electrical rad/s');legend('true','estimate','angle-derived');title([label,': four-state SPMSM, independent prescribed trajectory']);
nexttile;plot(t,a(:,50));grid on;ylabel('angle error / rad');
nexttile;plot(t,a(:,15:16));grid on;ylabel('innovation / A');legend('alpha','beta');
nexttile;semilogy(t,max(a(:,17),realmin));hold on;yline(r.configuration.MaxNIS,'--');grid on;ylabel('NIS / 1');legend('innovation statistic','qualification limit');
nexttile;plot(t,a(:,18));hold on;yline(r.configuration.MaxThetaStd,'--');grid on;ylabel('angle sigma / rad');
nexttile;yyaxis left;stairs(t,a(:,[12,23]));ylabel('flag / code');ylim([-.1,3.1]);
yyaxis right;stairs(t,a(:,22));ylabel('qualified samples');grid on;legend('valid','fault','qualified samples');xlabel('time / s');
export_pair(h,folder,[stem,'_capture']);clear cleanup;

h=figure('Visible','off','Position',[100,100,1150,1250]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');
q=data.records.speed_ramp;nexttile;plot(q.time,q.trace(:,[9,11]));grid on;ylabel('electrical rad/s');legend('true ramp','estimate');title([label,': dynamics and model sensitivity']);
nexttile;plot(q.time,q.trace(:,50));hold on;stairs(q.time,q.trace(:,12));grid on;ylabel('rad / flag');legend('ramp angle error','valid');
q=data.records.reversal;nexttile;plot(q.time,q.trace(:,[9,11,20]));grid on;ylabel('electrical rad/s');legend('true reversal','estimate','angle-derived');
q=data.records.dq_transient;nexttile;plot(q.time,q.trace(:,15:16));grid on;ylabel('innovation / A');legend('alpha','beta');
nexttile;hold on;cases={'rs_mismatch','L_mismatch','current_delay'};
for k=1:numel(cases),q=data.records.(cases{k});plot(q.time,q.trace(:,50));end
grid on;xlim([.15,.5]);ylabel('angle error / rad');legend('Rs +20%','L +20%','current age +Ts');xlabel('time / s');
export_pair(h,folder,[stem,'_dynamics']);clear cleanup;

h=figure('Visible','off','Position',[100,100,1150,1250]);cleanup=onCleanup(@()close_figure(h)); %#ok<NASGU>
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');
q=data.records.zero_speed;nexttile;plot(q.time,q.trace(:,[9,11]));hold on;stairs(q.time,q.trace(:,12));grid on;ylabel('rad/s / flag');legend('true zero','estimate','valid');title([label,': refusal, data fault and discretization']);
q=data.records.flux_mismatch;nexttile;plot(q.time,q.trace(:,17));hold on;yline(q.configuration.MaxNIS,'--');stairs(q.time,q.trace(:,12));grid on;ylabel('NIS / flag');legend('flux mismatch NIS','limit','valid');
q=data.records.wrong_direction;nexttile;plot(q.time,q.trace(:,[11,20]));hold on;stairs(q.time,q.trace(:,12));grid on;ylabel('rad/s / flag');legend('estimated speed','angle-derived speed','valid');
q=data.records.nonfinite_current;nexttile;stairs(q.time,q.trace(:,[12,23]));grid on;ylabel('flags / code');legend('valid','data fault');
nexttile;plot(r.time,r.trace(:,50));hold on;q=data.records.half_sample_time;plot(q.time,q.trace(:,50));grid on;xlim([.15,.5]);ylabel('angle error / rad');legend('Ts = 50 us','Ts = 25 us');xlabel('time / s');
export_pair(h,folder,[stem,'_validity']);
end
function export_pair(handle,folder,name)
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',150);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
function close_figure(handle)
if isgraphics(handle),close(handle);end
end
