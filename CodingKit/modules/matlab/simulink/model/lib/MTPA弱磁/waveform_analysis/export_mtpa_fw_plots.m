function export_mtpa_fw_plots()
%EXPORT_MTPA_FW_PLOTS Plot saved MIL records without rerunning models.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'results.mat'),'records');
r=data.records;
f=figure('Visible','off','Position',[100 100 1100 750]);tiledlayout(2,2);
a=r.mtpa.salient_mtpa;b=r.mtpa.salient_id_zero;c=r.mtpa.original_bipolar;
nexttile;plot(ch(a,'torque_request'),ch(a,'id_reference'),ch(c,'torque_request'),ch(c,'id_reference'));
grid on;xlabel('Requested torque / N m');ylabel('id / A');legend('Lq=6 mH','Lq=1.2 mH','Location','best');
nexttile;plot(ch(a,'torque_request'),hypot(ch(a,'id_reference'),ch(a,'iq_reference')),ch(b,'torque_request'),hypot(ch(b,'id_reference'),ch(b,'iq_reference')));
grid on;xlabel('Requested torque / N m');ylabel('Current magnitude / A');legend('MTPA','id=0','Location','best');
nexttile;plot(ch(a,'id_reference'),ch(a,'iq_reference'),ch(b,'id_reference'),ch(b,'iq_reference'));axis equal;grid on;
xlabel('id / A');ylabel('iq / A');legend('MTPA','id=0','Location','best');
nexttile;plot(a.trace.time,ch(a,'allocated_torque')-ch(a,'torque_request'));grid on;xlabel('Time / s');ylabel('Allocation residual / N m');
finish(f,folder,'mtpa_curves');

f=figure('Visible','off','Position',[100 100 1100 850]);tiledlayout(3,2);
a=r.fw.entry_exit;b=r.fw.bus_step;
nexttile;plot(a.trace.time,ch(a,'omega_e'));grid on;ylabel('we / rad/s');title('Speed entry and exit');
nexttile;plot(b.trace.time,ch(b,'bus_voltage'));grid on;ylabel('Vdc / V');title('DC bus step');
nexttile;plot(a.trace.time,[ch(a,'id_reference'),ch(a,'iq_reference'),ch(a,'id_fw')]);grid on;ylabel('Current / A');legend('id ref','iq ref','id FW');
nexttile;plot(b.trace.time,[ch(b,'id_reference'),ch(b,'iq_reference')]);grid on;ylabel('Current / A');legend('id ref','iq ref');
nexttile;plot(a.trace.time,[ch(a,'predicted_voltage'),ch(a,'voltage_available'),ch(a,'filtered_voltage')]);grid on;ylabel('Voltage / V');xlabel('Time / s');legend('predicted','available','filtered demand');
nexttile;plot(b.trace.time,[ch(b,'torque_request'),ch(b,'allocated_torque')]);grid on;ylabel('Torque / N m');xlabel('Time / s');legend('requested','allocated');
finish(f,folder,'fw_component');

f=figure('Visible','off','Position',[100 100 1100 800]);tiledlayout(2,2);a=r.motor.fw_on;b=r.motor.fw_off;
nexttile;plot(a.trace.time,ch(a,'speed_request'),a.trace.time,ch(a,'speed_truth'),b.trace.time,ch(b,'speed_truth'));grid on;
ylabel('Mechanical speed / rad/s');xlabel('Time / s');legend('request','FW on','FW off','Location','best');
nexttile;plot(a.trace.time,ch(a,'id_reference'),a.trace.time,ch(a,'iq_reference'),b.trace.time,ch(b,'id_reference'));grid on;
ylabel('Reference current / A');xlabel('Time / s');legend('id FW on','iq FW on','id FW off','Location','best');
nexttile;plot(a.trace.time,[ch(a,'voltage_demand_prev'),ch(a,'model_voltage_demand'),ch(a,'voltage_available')]);grid on;
ylabel('Voltage / V');xlabel('Time / s');legend('previous actual demand','model demand','available','Location','best');
nexttile;plot(a.trace.time,[ch(a,'torque_request'),ch(a,'allocated_torque'),ch(a,'electromagnetic_torque')]);grid on;
ylabel('Torque / N m');xlabel('Time / s');legend('requested','allocated','plant','Location','best');
finish(f,folder,'motor_fw_compare');

f=figure('Visible','off','Position',[100 100 1100 800]);tiledlayout(2,2);a=r.motor.unattainable_aw_on;b=r.motor.unattainable_aw_off;
nexttile;plot(a.trace.time,[ch(a,'speed_request'),ch(a,'speed_truth')]);grid on;ylabel('Mechanical speed / rad/s');legend('request','actual');
nexttile;plot(a.trace.time,ch(a,'speed_pi_integral'),b.trace.time,ch(b,'speed_pi_integral'));grid on;ylabel('Speed integral / N m');legend('tracking on','tracking off');
nexttile;plot(a.trace.time,[ch(a,'id_reference'),ch(a,'iq_reference')]);yline(a.parameters.refCfg.IdMin,'--');grid on;ylabel('Reference current / A');xlabel('Time / s');legend('id','iq','IdMin');
nexttile;plot(a.trace.time,[ch(a,'torque_request'),ch(a,'allocated_torque'),ch(a,'torque_residual')]);grid on;ylabel('Torque / N m');xlabel('Time / s');legend('requested','allocated','residual');
finish(f,folder,'motor_unattainable_aw');

f=figure('Visible','off','Position',[100 100 1100 800]);tiledlayout(2,2);a=r.motor.reverse_rotation;b=r.motor.exit_weakening;
nexttile;plot(a.trace.time,[ch(a,'speed_request'),ch(a,'speed_truth')]);grid on;ylabel('Mechanical speed / rad/s');title('Reverse rotation');legend('request','actual');
nexttile;plot(b.trace.time,[ch(b,'speed_request'),ch(b,'speed_truth')]);grid on;ylabel('Mechanical speed / rad/s');title('Exit field weakening');legend('request','actual');
nexttile;plot(a.trace.time,[ch(a,'id_reference'),ch(a,'iq_reference')]);grid on;ylabel('Reference current / A');xlabel('Time / s');legend('id','iq');
nexttile;plot(b.trace.time,[ch(b,'id_reference'),ch(b,'iq_reference'),ch(b,'id_fw')]);grid on;ylabel('Current / A');xlabel('Time / s');legend('id','iq','id FW');
finish(f,folder,'motor_reverse_exit');
end
function x=ch(r,name)
index=find(strcmp(r.channels,name),1);assert(~isempty(index),name);
x=r.trace.signals.values(:,index);
end
function finish(f,folder,name)
exportgraphics(f,fullfile(folder,[name,'.png']),'Resolution',150);
exportgraphics(f,fullfile(folder,[name,'.svg']),'ContentType','vector');
close(f);
end
