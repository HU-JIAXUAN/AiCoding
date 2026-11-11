function plot_mras_results()
%PLOT_MRAS_RESULTS Export capture, model sensitivity and refusal waveforms.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'results.mat'),'records');
r=data.records.positive;t=r.time;a=r.trace;
h=figure('Visible','off','Position',[100,100,1150,1150]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
nexttile;plot(t,a(:,[9,11,23]));grid on;ylabel('electrical rad/s');legend('true','estimated','PI integral');title('SPMSM current-model MRAS: independent prescribed trajectory');
nexttile;plot(t,a(:,26));grid on;ylabel('angle error / rad');
nexttile;plot(t,a(:,[15,13,16,14]));grid on;ylabel('dq current / A');legend('measured id','model id','measured iq','model iq');
nexttile;plot(t,a(:,[19,20]));hold on;stairs(t,a(:,12));grid on;ylabel('normalized / flag');legend('d residual / K','q residual / K','valid');xlabel('time / s');
export_pair(h,folder,'mras_capture');clear cleanup;

h=figure('Visible','off','Position',[100,100,1150,1150]);cleanup=onCleanup(@()close_figure(h));
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
q=data.records.speed_ramp;nexttile;plot(q.time,q.trace(:,[9,11]));grid on;ylabel('electrical rad/s');legend('true ramp','estimate');title('Ideal voltage balance: ramps, dq changes and parameter sensitivity');
q=data.records.dq_transient;nexttile;plot(q.time,q.trace(:,[15,13,16,14]));grid on;ylabel('dq current / A');legend('measured id','model id','measured iq','model iq');
nexttile;hold on;names={'rs_mismatch','L_mismatch','flux_mismatch','current_delay'};
for k=1:numel(names),q=data.records.(names{k});plot(q.time,q.trace(:,26));end
grid on;xlim([.15,.5]);ylabel('angle error / rad');legend('Rs +20%','L +20%','flux -10%','current age +Ts');
q=data.records.adc_noise;nexttile;plot(q.time,q.trace(:,11)-q.trace(:,9));grid on;xlim([.35,.5]);ylabel('speed error / rad/s');xlabel('time / s');title('1 mA RMS sampled-current noise, seed 42');
export_pair(h,folder,'mras_sensitivity');clear cleanup;

h=figure('Visible','off','Position',[100,100,1150,1150]);cleanup=onCleanup(@()close_figure(h)); %#ok<NASGU>
tiledlayout(4,1,'TileSpacing','compact','Padding','compact');
q=data.records.zero_speed;nexttile;plot(q.time,q.trace(:,[20,21,12]));grid on;ylabel('1 / V / flag');legend('normalized q','estimated EMF','valid');title('Refusal and reset: no static-position or unknown-direction claim');
q=data.records.wrong_direction;nexttile;plot(q.time,q.trace(:,[9,11]));hold on;stairs(q.time,q.trace(:,12));grid on;ylabel('rad/s / flag');legend('true speed','estimate with wrong prior','valid');
q=data.records.nonfinite_current;nexttile;stairs(q.time,q.trace(:,[12,24]));grid on;ylabel('flags / code');legend('valid','fault 1');
q=data.records.disable_restart;nexttile;plot(q.time,q.trace(:,26));hold on;stairs(q.time,q.trace(:,[6,12]));grid on;ylabel('rad / flags');legend('angle error','enable','valid');xlabel('time / s');
export_pair(h,folder,'mras_refusal');
end
function export_pair(handle,folder,stem)
exportgraphics(handle,fullfile(folder,[stem,'.png']),'Resolution',150);
exportgraphics(handle,fullfile(folder,[stem,'.svg']),'ContentType','vector');
end
function close_figure(handle)
if isgraphics(handle),close(handle);end
end
