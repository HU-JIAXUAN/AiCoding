function plot_flying_foc_results()
%PLOT_FLYING_FOC_RESULTS Export saved MIL data without opening figure windows.
folder=fileparts(mfilename('fullpath'));
a=load(fullfile(folder,'flying_forward.mat'));t=a.plant.time;
f=figure('Visible','off','Color','w','Position',[100,100,1100,900]);cleanup=onCleanup(@()close(f));
tiledlayout(4,1,'TileSpacing','compact');
nexttile;plot(t,a.plant.signals.values(:,11),t,a.observer.signals.values(:,6)/a.p.bridgeCfg.PolePairs,'--',t,a.plant.signals.values(:,30),':');
ylabel('Mechanical rad/s');legend('Plant','Estimated','Reference','Location','best');grid on;
nexttile;error=atan2(sin(a.observer.signals.values(:,19)-a.plant.signals.values(:,12)),cos(a.observer.signals.values(:,19)-a.plant.signals.values(:,12)));
plot(t,error);xlim([0.04,0.12]);ylabel('Angle error rad');grid on;
nexttile;plot(t,a.plant.signals.values(:,3:5));xlim([0.05,0.09]);ylabel('Phase current A');legend('ia','ib','ic');grid on;
nexttile;stairs(t,a.controller.signals.values(:,7));hold on;stairs(t,a.plant.signals.values(:,29));stairs(t,a.observer.signals.values(:,7));
xlim([0,0.15]);ylabel('State / logic');xlabel('Time s');legend('Sequence','PWM mode','Observer valid');grid on;
sgtitle('Flying capture: passive observation, PI precharge, PWM enable');
savePlot(f,folder,'flying_capture');clear cleanup;
a=load(fullfile(folder,'flying_observer_loss.mat'));t=a.plant.time;
f=figure('Visible','off','Color','w','Position',[100,100,1100,850]);cleanup=onCleanup(@()close(f));tiledlayout(3,1,'TileSpacing','compact');
nexttile;plot(t,a.plant.signals.values(:,3:5));xlim([0.599,0.604]);ylabel('Phase current A');legend('ia','ib','ic');grid on;
nexttile;stairs(t,a.plant.signals.values(:,15:17));hold on;plot(t,a.plant.signals.values(:,14),'k');
xlim([0.599,0.604]);ylabel('Diode state / A');legend('diode a','diode b','diode c','DC current');grid on;
nexttile;stairs(t,a.plant.signals.values(:,29));hold on;stairs(t,a.controller.signals.values(:,8));stairs(t,a.observer.signals.values(:,7));
xlim([0.599,0.604]);ylabel('Mode / logic');xlabel('Time s');legend('PWM mode','Fault code','Observer valid');grid on;
sgtitle('Observer loss: all gates off with passive diode current');savePlot(f,folder,'flying_shutdown');clear cleanup;
a=load(fullfile(folder,'flying_diode_rectification.mat'));t=a.plant.time;
f=figure('Visible','off','Color','w','Position',[100,100,1100,800]);cleanup=onCleanup(@()close(f));tiledlayout(3,1,'TileSpacing','compact');
nexttile;plot(t,a.plant.signals.values(:,3:5));xlim([0,0.04]);ylabel('Phase current A');legend('ia','ib','ic');grid on;
nexttile;plot(t,a.plant.signals.values(:,14)*a.p.bridgeCfg.Vdc);xlim([0,0.04]);ylabel('DC power W');grid on;
nexttile;stairs(t,a.plant.signals.values(:,29));hold on;stairs(t,a.controller.signals.values(:,8));
xlim([0,0.04]);ylabel('Mode / fault');xlabel('Time s');legend('PWM mode = 0','Fault code');grid on;
sgtitle('High back-EMF: passive rectification with PWM continuously off');savePlot(f,folder,'flying_rectification');
end
function savePlot(f,folder,name)
exportgraphics(f,fullfile(folder,[name,'.png']),'Resolution',160);
exportgraphics(f,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
