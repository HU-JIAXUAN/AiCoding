function plot_hfi_startup_results()
%PLOT_HFI_STARTUP_RESULTS Export actual MIL data without opening plot windows.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'startup_results.mat'),'records');r=data.records;
v=r.nominal;t=v.time;
handle=figure('Visible','off','Color','w','Position',[100,100,1150,1000]);tiledlayout(4,1);
nexttile;plot(t,[v.plant_trace(:,5),v.axis_trace(:,3),v.polarity_trace(:,4)]);
ylabel('Electrical rad');legend('Plant','HFI axis','Full position');grid on;
nexttile;stairs(t,[v.polarity_trace(:,8),v.polarity_trace(:,5),v.plant_trace(:,13)]);
ylabel('State');legend('Polarity stage','Position valid','Probe running');grid on;
nexttile;plot(t,v.polarity_trace(:,9:11));ylabel('Current A');legend('Positive peak','Negative peak','Difference');grid on;
nexttile;plot(t,v.polarity_trace(:,12:13));ylabel('Actual V s');xlabel('Time (s)');legend('Positive dose','Negative dose');grid on;
writeFigure(handle,folder,'startup_sequence');
handle=figure('Visible','off','Color','w','Position',[100,100,1150,750]);tiledlayout(2,1);
names={'nominal','opposite_polarity','adc_noise_12bit'};
nexttile;hold on;
for k=1:numel(names),v=r.(names{k});plot(v.time,v.error_trace(:,2));end
ylabel('Full error rad');legend(names,'Interpreter','none');grid on;
nexttile;hold on;for k=1:numel(names),v=r.(names{k});plot(v.time,v.polarity_trace(:,5));end
ylabel('Position valid');xlabel('Time (s)');grid on;writeFigure(handle,folder,'startup_polarity');
handle=figure('Visible','off','Color','w','Position',[100,100,1150,1000]);tiledlayout(3,1);
names={'nominal','no_saturation','unequal_actual_pulses'};
nexttile;hold on;for k=1:numel(names),v=r.(names{k});plot(v.time,v.polarity_trace(:,11));end
ylabel('Peak difference A');legend(names,'Interpreter','none');grid on;
nexttile;hold on;for k=1:numel(names),v=r.(names{k});plot(v.time,v.polarity_trace(:,12)-v.polarity_trace(:,13));end
ylabel('Dose mismatch V s');grid on;
nexttile;hold on;for k=1:numel(names),v=r.(names{k});stairs(v.time,v.polarity_trace(:,14));end
ylabel('Fault code');xlabel('Time (s)');grid on;writeFigure(handle,folder,'startup_rejection');
end
function writeFigure(handle,folder,name)
cleanup=onCleanup(@()close(handle)); %#ok<NASGU>
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',140);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
