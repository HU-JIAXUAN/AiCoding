function export_extension_foc_plots(folder)
%EXPORT_EXTENSION_FOC_PLOTS Recreate figures from the forty preserved App cases.
if nargin<1,folder=fileparts(mfilename('fullpath'));end
for algorithms={'mras','ekf','ukf','sigmoid'}
    kind=algorithms{1};a=load(fullfile(folder,kind,'forward.mat'));r=a.record;
    t=r.controller.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
    cp=r.plant.columns;co=r.observer.columns;cc=r.controller.columns;
    f=figure('Visible','off','Position',[100 100 1300 1000]);clean=onCleanup(@()close(f));
    subplot(5,1,1);plot(t,[r.controller.trace(:,cc.speed_reference),r.plant.trace(ip,cp.speed_mechanical),r.observer.trace(:,co.omega_hat)/r.parameters.pmsmCfg.PolePairs]);ylabel('Mechanical rad/s');legend('reference','physical','estimated','Location','best');grid on
    subplot(5,1,2);plot(t,wrap(r.observer.trace(:,co.theta_hat)-r.plant.trace(ip,cp.theta_e)));ylabel('Electrical error rad');grid on
    subplot(5,1,3);plot(t,[r.controller.trace(:,cc.reference),r.plant.trace(ip,[cp.id_true,cp.iq_true])]);ylabel('Current A');legend('id ref','iq ref','id true','iq true','Location','best');grid on
    subplot(5,1,4);plot(t,[r.observer.trace(:,co.observer_residual),r.parameters.handoverCfg.MaxResidual*ones(size(t))]);ylabel('Residual A');legend('residual','handover limit','Location','best');grid on
    subplot(5,1,5);plot(t,[r.controller.trace(:,cc.handover_mode),r.controller.trace(:,cc.run),r.observer.trace(:,co.valid)]);ylabel('Mode / flag');xlabel('Time s');legend('handover','gates','valid','Location','best');grid on
    sgtitle([upper(kind) ' physical sensorless FOC']);write(f,folder,[kind '_closed_loop']);clear clean

    a=load(fullfile(folder,kind,'observer_loss.mat'));r=a.record;t=r.controller.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
    cp=r.plant.columns;co=r.observer.columns;cc=r.controller.columns;
    f=figure('Visible','off','Position',[100 100 1300 850]);clean=onCleanup(@()close(f));
    subplot(3,1,1);plot(t,[r.observer.trace(:,co.enable),r.observer.trace(:,co.valid),r.controller.trace(:,cc.run),r.controller.trace(:,cc.handover_fault)]);ylabel('Enable / gate / fault');legend('observer enabled','valid','gates','fault','Location','best');xlim([1.545 1.56]);grid on
    subplot(3,1,2);keep=r.plant.time>=1.545&r.plant.time<=1.56;plot(r.plant.time(keep),r.plant.trace(keep,cp.phase_current));ylabel('Physical phase A');xlim([1.545 1.56]);grid on
    subplot(3,1,3);plot(t,[r.plant.trace(ip,cp.speed_mechanical),r.observer.trace(:,co.omega_hat)/r.parameters.pmsmCfg.PolePairs]);ylabel('Mechanical rad/s');xlabel('Time s');legend('physical','estimate','Location','best');xlim([1.45 1.8]);grid on
    sgtitle([upper(kind) ' observer-loss shutdown']);write(f,folder,[kind '_observer_loss']);clear clean
end
f=figure('Visible','off','Position',[100 100 1300 850]);clean=onCleanup(@()close(f));
labels={'MRAS','EKF','UKF','sigmoid'};algorithms={'mras','ekf','ukf','sigmoid'};
for k=1:numel(algorithms)
    a=load(fullfile(folder,algorithms{k},'observer_resistance_mismatch.mat'));r=a.record;t=r.controller.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
    subplot(2,1,1);hold on;plot(t,r.plant.trace(ip,r.plant.columns.speed_mechanical)-r.parameters.focCfg.SpeedReference);
    subplot(2,1,2);hold on;plot(t,wrap(r.observer.trace(:,r.observer.columns.theta_hat)-r.plant.trace(ip,r.plant.columns.theta_e)));
end
subplot(2,1,1);ylabel('Physical speed error rad/s');xlim([1.6 2.2]);legend(labels,'Location','best');grid on
subplot(2,1,2);ylabel('Electrical angle error rad');xlabel('Time s');xlim([1.6 2.2]);legend(labels,'Location','best');grid on
sgtitle('Observer resistance +15%, unchanged physical motor');write(f,folder,'extension_resistance_comparison');clear clean
end
function value=wrap(value)
value=atan2(sin(value),cos(value));
end
function write(fig,folder,name)
exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',140);
exportgraphics(fig,fullfile(folder,[name '.svg']),'ContentType','vector');
end
