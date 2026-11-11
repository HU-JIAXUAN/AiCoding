function plot_hfi_probe_results()
%PLOT_HFI_PROBE_RESULTS Export measured tensor, isotropic and ADC comparisons.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'probe_results.mat'),'records');r=data.records;
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1100,850]);tiledlayout(3,1);
v=r.nominal_locked.trace;t=r.nominal_locked.time;
nexttile;plot(t,v(:,[5,12]));ylabel('Electrical rad');legend('Plant','Axis snapshot');grid on;
nexttile;plot(t,v(:,[17,18,19]));ylabel('Inverse H');legend('aa','ab','bb');grid on;
nexttile;plot(t,v(:,[14,15]));ylabel('State');xlabel('Time (s)');legend('Qualified','Done');grid on;
exportFigure(figureHandle,folder,'probe_tensor');
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1100,850]);tiledlayout(2,1);
names={'nominal_locked','round_1mH','round_1p2mH','round_adc'};
nexttile;hold on;
for k=1:numel(names),v=r.(names{k});plot(v.time,v.trace(:,13));end
ylabel('Saliency ratio');legend(names,'Interpreter','none');grid on;
nexttile;hold on;for k=1:numel(names),v=r.(names{k});plot(v.time,v.trace(:,14));end
ylabel('Qualified');xlabel('Time (s)');grid on;exportFigure(figureHandle,folder,'probe_isotropic');
figureHandle=figure('Visible','off','Color','w','Position',[100,100,1100,850]);tiledlayout(3,1);
v=r.adc_noise_12bit.trace;t=r.adc_noise_12bit.time;
nexttile;plot(t,v(:,27:29));ylabel('ADC current A');legend('a','b','c');grid on;
nexttile;plot(t,v(:,26));ylabel('Axis error rad');grid on;
nexttile;plot(t,v(:,[13,20,14]));ylabel('Ratio / residual / valid');xlabel('Time (s)');legend('Saliency','Fit residual','Qualified');grid on;
exportFigure(figureHandle,folder,'probe_adc');
end
function exportFigure(handle,folder,name)
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',140);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');close(handle);
end
