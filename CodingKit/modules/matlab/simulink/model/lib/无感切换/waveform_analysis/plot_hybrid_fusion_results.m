function plot_hybrid_fusion_results()
%PLOT_HYBRID_FUSION_RESULTS Export analytic fusion and fault traces without windows.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'fusion_results.mat'),'records');
r=data.records.round_trip;t=r.time;y=r.trace(:,11:27);u=r.stimulus.signals.values;
validError=r.angle_error;validError(y(:,4)<.5)=NaN;
h=figure('Visible','off','Position',[100,100,1200,1300]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t,u(:,10),'LineWidth',1.2);ylabel('electrical rad/s');ylim([10,110]);grid on;title('Independent trackers: low to high to low, including a returned pi branch');
nexttile;plot(t,[wrap(u(:,1)-u(:,9)),wrap(u(:,4)-u(:,9))]);ylabel('candidate error / rad');legend('low raw candidate','high candidate','Location','west');grid on;
nexttile;plot(t,[validError,y(:,12)],'LineWidth',1);ylabel('rad');legend('fused error while valid','pair phase gap','Location','west');grid on;
nexttile;plot(t,y(:,[5,6]),'LineWidth',1.2);ylabel('fraction');legend('high weight','HFI injection','Location','west');ylim([-.05,1.05]);grid on;
nexttile;stairs(t,y(:,[9,10,11,17]));ylabel('flags');legend('low qualified','high qualified','extra pi','branch ready','Location','west');xlabel('time / s');ylim([-.1,1.1]);grid on;
exportgraphics(h,fullfile(folder,'fusion_round_trip.png'),'Resolution',150);
exportgraphics(h,fullfile(folder,'fusion_round_trip.svg'),'ContentType','vector');clear cleanup;

h=figure('Visible','off','Position',[100,100,1200,1100]);cleanup=onCleanup(@()close_figure(h)); %#ok<NASGU>
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
names={'high_dropout_short','high_dropout_long','phase_jump_high','unanchored_return'};
titles={'0.5 ms dropout: predict and recover','Long dropout: latched source-loss fault', ...
    'Persistent phase jump: innovation rejection','No high anchor for low return: refuse takeover'};
for k=1:4
    r=data.records.(names{k});y=r.trace(:,11:27);
    nexttile;stairs(r.time,y(:,[4,6,8]),'LineWidth',1.1);title(titles{k});grid on;
    if k<4,xlim([.59,.615]);else,xlim([.79,.815]);end
    ylabel('valid / scale / code');ylim([-.1,1.1]);
    if k==1,legend('fusion valid','injection scale','fault','Location','east');end
end
xlabel('time / s');
exportgraphics(h,fullfile(folder,'fusion_faults.png'),'Resolution',150);
exportgraphics(h,fullfile(folder,'fusion_faults.svg'),'ContentType','vector');
end
function close_figure(handle)
if isgraphics(handle),close(handle);end
end
function result=wrap(angle)
result=atan2(sin(angle),cos(angle));
end
