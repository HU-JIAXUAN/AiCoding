function plot_sigmoid_smo_results()
%PLOT_SIGMOID_SMO_RESULTS Export hidden figures; preserve original noise failure.
module=initialize_sigmoid_smo_paths();folder=fullfile(module,'waveform_analysis');
data=load(fullfile(folder,'sigmoid_results.mat'),'records');a=data.records.positive;t=a.time;v=a.trace;
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1400,950]);cleanup=onCleanup(@()close(figureHandle));
layout=tiledlayout(3,2,'TileSpacing','compact');title(layout,'Sigmoid SMO: independent SPMSM, 200 electrical rad/s');
nexttile;plot(t,[unwrap(v(:,8)),unwrap(v(:,10))]);ylabel('electrical angle (rad)');legend('true','estimated','Location','northwest');grid on;
nexttile;plot(t,v(:,24));ylabel('wrapped angle error (rad)');grid on;
nexttile;plot(t,v(:,[9,11]));ylabel('electrical speed (rad/s)');legend('true','estimated');grid on;
nexttile;plot(t,v(:,[13,14,20]));ylabel('injection / EMF estimate (V)');legend('alpha','beta','magnitude');grid on;
nexttile;plot(t,v(:,[3,15]));ylabel('alpha current (A)');xlabel('time (s)');legend('measured','estimated');grid on;
nexttile;plot(t,v(:,[17,18,23]));ylabel('current residual (A)');xlabel('time (s)');legend('alpha','beta','norm');grid on;
exportPair(figureHandle,folder,'sigmoid_capture');clear cleanup;
b=data.records.measurement_noise_5mA;c=data.records.noise_10mA_qualification_drop;q=c.time>=c.metrics.window_start_s;
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1200,950]);cleanup=onCleanup(@()close(figureHandle));
layout=tiledlayout(3,1,'TileSpacing','compact');title(layout,'Noise limitation: unchanged PLL threshold and 100-sample qualification');
nexttile;plot(c.time(q),c.trace(q,21));hold on;yline(c.pll.LockError,'--');yline(-c.pll.LockError,'--');ylabel('PLL phase error (rad)');grid on;
nexttile;stairs(b.time(q),b.trace(q,12),'LineWidth',1.3);hold on;stairs(c.time(q),c.trace(q,12));ylim([-.1,1.1]);
ylabel('valid (0/1)');legend('5 mA noise','10 mA noise');grid on;
nexttile;plot(b.time(q),b.trace(q,24),c.time(q),c.trace(q,24));ylabel('wrapped angle error (rad)');xlabel('time (s)');legend('5 mA noise','10 mA noise');grid on;
exportPair(figureHandle,folder,'sigmoid_noise');clear cleanup;
comparison=load(fullfile(folder,'sigmoid_comparison_results.mat'),'report');m=comparison.report.comparisons;
errors=zeros(3,3);valid=zeros(3,2);
for k=1:3
    errors(k,:)=[m(2*k-1).basic_angle_rms,m(2*k).basic_angle_rms,m(2*k).sigmoid_angle_rms];
    valid(k,:)=[m(2*k).basic_valid_fraction,m(2*k).sigmoid_valid_fraction];
end
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1250,750]);cleanup=onCleanup(@()close(figureHandle));
layout=tiledlayout(2,1,'TileSpacing','compact');title(layout,'Matched input, K=60 V, origin slope=18 V/A and PLL');
labels=categorical({'200 rad/s','600 rad/s','200 rad/s + 10 mA'});labels=reordercats(labels,{'200 rad/s','600 rad/s','200 rad/s + 10 mA'});
nexttile;bar(labels,errors);ylabel('angle RMS (rad)');legend('basic LPF, no compensation','basic LPF, compensated','sigmoid, no LPF','Location','northwest');grid on;
nexttile;bar(labels,valid);ylim([0,1.08]);ylabel('valid fraction');legend('basic LPF, compensated','sigmoid, no LPF','Location','southwest');grid on;
exportPair(figureHandle,folder,'sigmoid_comparison');clear cleanup;
end
function exportPair(handle,folder,name)
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',160);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
