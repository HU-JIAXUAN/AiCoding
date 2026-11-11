function export_sensorless_fw_plots(folder)
%EXPORT_SENSORLESS_FW_PLOTS Recreate PNG/SVG figures from preserved MAT records.
if nargin<1,folder=fileparts(mfilename('fullpath'));end
core=fullfile(folder,'guarded_core');edges=fullfile(folder,'edges');
a=load(fullfile(core,'forward_high_speed.mat'));r=a.record;
f=figure('Visible','off','Position',[100 100 1300 950]);clean=onCleanup(@()close(f));
t=r.controller.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
subplot(4,1,1);plot(t,[r.controller.trace(:,r.controller.columns.speed_reference),r.plant.trace(ip,r.plant.columns.speed_mechanical)]);ylabel('Mechanical rad/s');legend('reference','actual','Location','best');grid on
subplot(4,1,2);plot(t,[r.allocation.trace(:,r.allocation.columns.id_reference),r.plant.trace(ip,r.plant.columns.id_true),r.allocation.trace(:,r.allocation.columns.iq_reference),r.plant.trace(ip,r.plant.columns.iq_true)]);ylabel('Current A');legend('id ref','id true','iq ref','iq true','Location','best');grid on
subplot(4,1,3);plot(t,[r.allocation.trace(:,r.allocation.columns.filtered_voltage),r.allocation.trace(:,r.allocation.columns.voltage_available),r.allocation.trace(:,r.allocation.columns.predicted_voltage)]);ylabel('Voltage V');legend('demand filtered','available','predicted','Location','best');grid on
subplot(4,1,4);plot(t,[r.controller.trace(:,r.controller.columns.handover_mode),r.guard.trace(:,r.guard.columns.permit),r.allocation.trace(:,r.allocation.columns.fw_active)]);ylabel('Mode / flag');xlabel('Time s');legend('handover','start permit','FW active','Location','best');grid on
write(f,folder,'fw_nominal');clear clean

a=load(fullfile(core,'bus_drop_recovery.mat'));r=a.record;t=r.allocation.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
f=figure('Visible','off','Position',[100 100 1300 850]);clean=onCleanup(@()close(f));
subplot(3,1,1);plot(t,[r.allocation.trace(:,r.allocation.columns.bus_voltage),r.allocation.trace(:,r.allocation.columns.voltage_available)]);ylabel('Voltage V');legend('actual Vdc','available dq','Location','best');grid on
subplot(3,1,2);plot(t,[r.allocation.trace(:,r.allocation.columns.id_reference),r.plant.trace(ip,r.plant.columns.id_true),r.plant.trace(ip,r.plant.columns.iq_true)]);ylabel('Current A');legend('id ref','id true','iq true','Location','best');grid on
subplot(3,1,3);plot(t,[r.controller.trace(:,r.controller.columns.speed_reference),r.plant.trace(ip,r.plant.columns.speed_mechanical)]);ylabel('Mechanical rad/s');xlabel('Time s');legend('reference','actual','Location','best');grid on
write(f,folder,'fw_bus');clear clean

a=load(fullfile(core,'forward_regeneration.mat'));r=a.record;t=r.plant.time;keep=1:10:numel(t);c=r.plant.columns;x=r.plant.trace;
f=figure('Visible','off','Position',[100 100 1300 850]);clean=onCleanup(@()close(f));
subplot(3,1,1);plot(t(keep),x(keep,c.speed_mechanical));ylabel('Mechanical rad/s');grid on
subplot(3,1,2);plot(t(keep),[x(keep,c.torque),x(keep,c.load_torque)]);ylabel('Torque N m');legend('motor','load','Location','best');grid on
subplot(3,1,3);plot(t(keep),[x(keep,c.bus_voltage).*x(keep,c.dc_current),x(keep,c.torque).*x(keep,c.speed_mechanical)]);ylabel('Power W');xlabel('Time s');legend('bus','electromagnetic','Location','best');grid on
write(f,folder,'fw_regeneration');clear clean

a=load(fullfile(edges,'direction_stop_then_restart.mat'));r=a.record;t=r.guard.time;ip=round(t/r.parameters.bridgeCfg.Ts)+1;
f=figure('Visible','off','Position',[100 100 1300 950]);clean=onCleanup(@()close(f));
subplot(4,1,1);plot(t,[r.actuation.trace(:,1),r.plant.trace(ip,r.plant.columns.speed_mechanical)]);ylabel('Mechanical rad/s');legend('requested','actual','Location','best');grid on
subplot(4,1,2);plot(t,[r.guard.trace(:,r.guard.columns.emf_magnitude),ones(size(t))*r.parameters.startGuardCfg.MaxStartEmf]);ylabel('Observed EMF V');legend('observed','restart limit','Location','best');grid on
subplot(4,1,3);plot(t,[r.guard.trace(:,r.guard.columns.permit),r.controller.trace(:,r.controller.columns.run),r.controller.trace(:,r.controller.columns.handover_mode)]);ylabel('Permit / mode');legend('permit','gates','handover','Location','best');grid on
subplot(4,1,4);plot(t,r.plant.trace(ip,r.plant.columns.phase_current));ylabel('Phase current A');xlabel('Time s');grid on
write(f,folder,'fw_restart');clear clean

a=load(fullfile(edges,'moving_forward_refused.mat'));b=load(fullfile(edges,'moving_alignment_bypass_counterexample.mat'));
f=figure('Visible','off','Position',[100 100 1300 750]);clean=onCleanup(@()close(f));
subplot(2,1,1);plot(a.record.plant.time,a.record.plant.trace(:,a.record.plant.columns.speed_mechanical),b.record.plant.time,b.record.plant.trace(:,b.record.plant.columns.speed_mechanical));ylabel('Mechanical rad/s');legend('interlock enabled','bypass counterexample','Location','best');grid on
subplot(2,1,2);plot(a.record.plant.time,hypot(a.record.plant.trace(:,a.record.plant.columns.id_true),a.record.plant.trace(:,a.record.plant.columns.iq_true)),b.record.plant.time,hypot(b.record.plant.trace(:,b.record.plant.columns.id_true),b.record.plant.trace(:,b.record.plant.columns.iq_true)));ylabel('Physical dq magnitude A');xlabel('Time s');legend('interlock enabled','bypass counterexample','Location','best');grid on
write(f,folder,'fw_start_refusal');clear clean
end
function write(fig,folder,name)
exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',140);
exportgraphics(fig,fullfile(folder,[name '.svg']),'ContentType','vector');
end
