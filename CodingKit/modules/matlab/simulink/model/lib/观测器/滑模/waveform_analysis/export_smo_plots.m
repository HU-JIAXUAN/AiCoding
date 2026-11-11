function export_smo_plots(folder)
%EXPORT_SMO_PLOTS Render saved SMO results without repeating simulations.
if nargin<1,folder=fileparts(mfilename('fullpath'));end
data=load(fullfile(folder,'results.mat'),'records');records=data.records;
plotCase(records.positive,folder,'tracking');plotCase(records.reversal,folder,'reversal');
f=figure('Visible','off');plot(records.positive.time,[records.positive.trace(:,22),records.without_compensation.trace(:,22)]);
xlabel('time / s');ylabel('angle error / rad');legend({'compensated','uncompensated'});grid on;
exportgraphics(f,fullfile(folder,'compensation.png'));exportgraphics(f,fullfile(folder,'compensation.svg'),'ContentType','vector');close(f);
end
function plotCase(r,folder,name)
f=figure('Visible','off','Position',[100 100 1100 850]);t=r.time;v=r.trace;
tiledlayout(4,1);nexttile;plot(t,[v(:,9),v(:,11)]);ylabel('electrical rad/s');legend({'true','SMO + PLL'});grid on;
nexttile;plot(t,v(:,22));ylabel('angle error / rad');grid on;
nexttile;plot(t,[v(:,3),v(:,15),v(:,4),v(:,16)]);ylabel('current / A');legend({'ia','ia hat','ib','ib hat'});grid on;
nexttile;stairs(t,[v(:,5),v(:,12)]);ylabel('direction / valid');xlabel('time / s');legend({'direction','valid'});grid on;
exportgraphics(f,fullfile(folder,[name,'.png']));exportgraphics(f,fullfile(folder,[name,'.svg']),'ContentType','vector');close(f);
end
