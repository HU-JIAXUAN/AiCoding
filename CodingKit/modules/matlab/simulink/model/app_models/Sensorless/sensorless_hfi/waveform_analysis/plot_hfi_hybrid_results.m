function plot_hfi_hybrid_results()
%PLOT_HFI_HYBRID_RESULTS Export physical handover, ripple and fault waveforms.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'hybrid_results.mat'),'records');
r=data.records.round_trip;t=r.time;f=r.fusion_trace;p=r.plant_trace;c=r.controller_trace;
polePairs=r.parameters.Motor.PolePairs;slow=1:20:numel(t);
h=figure('Visible','off','Position',[100,100,1200,1250]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t(slow),[c(slow,1),p(slow,4)/polePairs,c(slow,2)]);ylabel('mechanical rad/s');legend('profile','physical','estimated');grid on;title('Physical PMSM: HFI startup, EEMF takeover and HFI return');
phase=r.angle_error;phase(r.state_trace(:,4)<.5)=NaN;emfPhase=wrap(r.emf_trace(:,1)-p(:,3));emfPhase(r.emf_trace(:,3)<.5)=NaN;
nexttile;plot(t,[phase,emfPhase]);ylabel('angle error / rad');legend('fused while active','EEMF while valid');grid on;
nexttile;plot(t(slow),f(slow,[5,6]),'LineWidth',1.2);ylabel('fraction');legend('high weight','HFI injection');grid on;ylim([-.05,1.05]);
nexttile;plot(t,[c(:,5),p(:,5),r.stimulus.signals.values(:,1)]);ylabel('torque / Nm');legend('request','physical','load');grid on;
nexttile;stairs(t,f(:,[9,10,11,17]));ylabel('flags');legend('low qualified','high qualified','extra pi','branch ready');grid on;ylim([-.1,1.1]);xlabel('time / s');
export_pair(h,folder,'hybrid_round_trip');clear cleanup;

h=figure('Visible','off','Position',[100,100,1200,1000]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
windows={[1.0,1.003],[2.15,2.153]};
for k=1:2
    mask=t>=windows{k}(1) & t<=windows{k}(2);
    nexttile;plot(t(mask),[p(mask,6),p(mask,7),c(mask,7),c(mask,6)]);ylabel('dq current / A');grid on;
    if k==1,title('High region: injection removed, original 50 us samples');else,title('Low return: HFI ripple, original 50 us samples');end
    legend('physical id','physical iq','id reference','iq reference');
    nexttile;plot(t(mask),r.axis_trace(mask,1:2));ylabel('HFI voltage / V');grid on;legend('alpha','beta');
end
xlabel('time / s');export_pair(h,folder,'hybrid_ripple');clear cleanup;

h=figure('Visible','off','Position',[100,100,1200,1150]);cleanup=onCleanup(@()close_figure(h));
q=data.records.shifted_dwell;t=q.time;f=q.fusion_trace;p=q.plant_trace;
candidate=wrap(q.polarity_trace(:,4)-p(:,3));candidate(q.polarity_trace(:,5)<.5)=NaN;
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t,[candidate,q.angle_error]);ylabel('angle error / rad');legend('raw low candidate','fused');grid on;title('Physical pi-branch return after a different high-speed dwell');xlim([1.55,2.15]);
nexttile;phase=q.angle_error;phase(q.state_trace(:,4)<.5)=NaN;plot(t,phase);ylabel('fused error / rad');grid on;xlim([1.55,2.15]);
nexttile;stairs(t,f(:,[5,6,11,17]));ylabel('fraction / flags');legend('high weight','injection','extra pi','branch ready');grid on;xlim([1.55,2.15]);
nexttile;plot(t,[p(:,6:7),q.controller_trace(:,[7,6])]);ylabel('dq current / A');legend('physical id','physical iq','id reference','iq reference');grid on;xlim([1.55,2.15]);xlabel('time / s');
export_pair(h,folder,'hybrid_branch_return');clear cleanup;

h=figure('Visible','off','Position',[100,100,1200,1100]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
names={'high_gap_overlap','high_loss_high','low_loss_then_stop','adc_current_fault'};
for k=1:4
    q=data.records.(names{k});nexttile;
    stairs(q.time,[q.state_trace(:,4),q.fusion_trace(:,5),q.fusion_trace(:,6),q.state_trace(:,7),q.fusion_trace(:,8)]);grid on;
    title(strrep(names{k},'_',' '));ylabel('flags / fraction / code');
    if k==1,xlim([.4,.55]);elseif k==3,xlim([1.4,2.1]);else,xlim([.92,1.03]);end
    if k==1,legend('control active','high weight','injection','App fault','fusion fault');end
end
xlabel('time / s');export_pair(h,folder,'hybrid_faults');clear cleanup;

q=data.records.command_reverse;t=q.time;f=q.fusion_trace;p=q.plant_trace;
h=figure('Visible','off','Position',[100,100,1200,1050]);cleanup=onCleanup(@()close_figure(h)); %#ok<NASGU>
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t,[q.controller_trace(:,1),p(:,4)/q.parameters.Motor.PolePairs,q.controller_trace(:,2)]);ylabel('mechanical rad/s');legend('profile','physical','estimated');grid on;title('Physical reversal through zero and both observer regions');
nexttile;plot(t,f(:,[5,6]));ylabel('fraction');legend('high weight','injection');grid on;
nexttile;phase=q.angle_error;phase(q.state_trace(:,4)<.5)=NaN;plot(t,phase);ylabel('fused error / rad');grid on;
nexttile;stairs(t,[q.observer_state_trace(:,1),f(:,[9,10,11,17])]);ylabel('direction / flags');legend('estimated direction','low Q','high Q','extra pi','branch ready');grid on;xlabel('time / s');
export_pair(h,folder,'hybrid_reversal');
end
function export_pair(handle,folder,name)
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',150);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
function close_figure(handle)
if isgraphics(handle),close(handle);end
end
function result=wrap(angle)
result=atan2(sin(angle),cos(angle));
end
