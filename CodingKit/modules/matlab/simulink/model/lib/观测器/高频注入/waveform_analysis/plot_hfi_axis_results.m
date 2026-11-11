function plot_hfi_axis_results()
%PLOT_HFI_AXIS_RESULTS Export physical-response evidence from saved MIL traces.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'axis_results.mat'),'records');
r=data.records;figureHandle=figure('Visible','off','Color','w');
record=r.free_rotor;t=record.time;v=record.trace;
tiledlayout(3,1);
nexttile;plot(t,v(:,[7,14]));ylabel('Electrical rad');legend('Plant','Axis');grid on;
nexttile;plot(t,v(:,[26,27]));ylabel('Error rad');legend('Modulo pi','Full angle');grid on;
nexttile;plot(t,v(:,[16,18]));ylabel('Valid / A');xlabel('Time (s)');legend('Axis valid','Response');grid on;
save_figure(figureHandle,folder,'axis_tracking');
figureHandle=figure('Visible','off','Color','w');tiledlayout(2,1);
record=r.opposite_polarity;t=record.time;v=record.trace;
nexttile;plot(t,v(:,[7,14]));ylabel('Electrical rad');legend('Plant','Axis branch');grid on;
nexttile;plot(t,v(:,[26,27]));ylabel('Error rad');xlabel('Time (s)');legend('Modulo pi','Full angle');grid on;
save_figure(figureHandle,folder,'axis_pi_ambiguity');
figureHandle=figure('Visible','off','Color','w');tiledlayout(2,1);
names={'nominal_locked','current_delay_unaligned','current_delay_aligned'};
nexttile;hold on;for k=1:numel(names),record=r.(names{k});plot(record.time,record.trace(:,26));end
ylabel('Axis error rad');legend(names,'Interpreter','none');grid on;
nexttile;hold on;for k=1:numel(names),record=r.(names{k});plot(record.time,record.trace(:,16));end
ylabel('Axis valid');xlabel('Time (s)');grid on;
save_figure(figureHandle,folder,'axis_sample_age');
figureHandle=figure('Visible','off','Color','w');tiledlayout(3,1);
record=r.adc_noise_12bit;t=record.time;v=record.trace;
nexttile;plot(t,v(:,28:30));ylabel('Phase current A');legend('a','b','c');grid on;
nexttile;plot(t,v(:,26));hold on;
if isfield(r,'adc_unfiltered'),plot(r.adc_unfiltered.time,r.adc_unfiltered.trace(:,26));legend('300 Hz LPF','Unfiltered');end
ylabel('Axis error rad');grid on;
nexttile;plot(t,v(:,16));hold on;
if isfield(r,'adc_unfiltered'),plot(r.adc_unfiltered.time,r.adc_unfiltered.trace(:,16));legend('300 Hz LPF','Unfiltered');end
ylabel('Axis valid');xlabel('Time (s)');grid on;
save_figure(figureHandle,folder,'axis_adc');
end
function save_figure(handle,folder,name)
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',140);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');close(handle);
end
