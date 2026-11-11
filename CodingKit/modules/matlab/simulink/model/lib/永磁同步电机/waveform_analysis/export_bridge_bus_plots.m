function export_bridge_bus_plots(folder)
%EXPORT_BRIDGE_BUS_PLOTS Export measured MIL data with task figures hidden.
if nargin<1,folder=fileparts(mfilename('fullpath'));end
data=load(fullfile(folder,'bus_pwm_steps.mat'),'r');r=data.r;c=r.columns;
f=figure('Visible','off','Color','w','Position',[80,80,1100,800]);
cleanup=onCleanup(@()close(f));tiledlayout(f,3,1);
nexttile;plot(r.time,r.stimulus.signals.values(:,6),'LineWidth',1.3);grid on;
ylabel('V_{dc} (V)');title('Prescribed DC bus drop and recovery, PWM mode');
nexttile;plot(r.time,r.trace(:,c.phase_current),'LineWidth',1);grid on;
ylabel('Phase current (A)');legend('i_a','i_b','i_c','Location','best');
nexttile;plot(r.time,r.trace(:,c.voltage_ab),'LineWidth',1.1);grid on;
ylabel('u_{alpha,beta} (V)');xlabel('Time (s)');legend('u_{alpha}','u_{beta}','Location','best');
write(f,folder,'bus_pwm_steps');clear cleanup

data=load(fullfile(folder,'bus_off_rectification.mat'),'r');r=data.r;c=r.columns;
f=figure('Visible','off','Color','w','Position',[80,80,1100,800]);
cleanup=onCleanup(@()close(f));tiledlayout(f,3,1);
nexttile;plot(r.time,r.stimulus.signals.values(:,6),'LineWidth',1.3);grid on;
ylabel('V_{dc} (V)');title('All gates off: externally held rotor, passive rectification');
nexttile;plot(r.time,r.trace(:,c.dc_current),'LineWidth',1.2);grid on;
ylabel('i_{dc} (A)');
nexttile;plot(r.time,r.trace(:,c.phase_current),'LineWidth',1);grid on;
ylabel('Phase current (A)');xlabel('Time (s)');legend('i_a','i_b','i_c','Location','best');
write(f,folder,'bus_off_rectification');clear cleanup

data=load(fullfile(folder,'bus_energy_refinement.mat'),'coarse','fine');
[coarseEnergy,coarseIntegral]=energy(data.coarse);[fineEnergy,fineIntegral]=energy(data.fine);
f=figure('Visible','off','Color','w','Position',[80,80,1100,700]);
cleanup=onCleanup(@()close(f));tiledlayout(f,2,1);
nexttile;plot(data.coarse.time,coarseEnergy-coarseEnergy(1),'LineWidth',1.3);hold on;
plot(data.coarse.time,coarseIntegral,'--','LineWidth',1.1);grid on;
ylabel('Energy change (J)');legend('State energy','Integrated input minus losses','Location','best');
title('Energy accounting with a prescribed DC rail');
nexttile;plot(data.coarse.time,abs(coarseEnergy-coarseEnergy(1)-coarseIntegral),'LineWidth',1.2);hold on;
plot(data.fine.time,abs(fineEnergy-fineEnergy(1)-fineIntegral),'LineWidth',1.2);grid on;
ylabel('Cumulative defect (J)');xlabel('Time (s)');legend('5 us','2.5 us','Location','best');
write(f,folder,'bus_energy_refinement');clear cleanup
end
function write(f,folder,name)
exportgraphics(f,fullfile(folder,[name,'.png']),'Resolution',150);
print(f,fullfile(folder,[name,'.svg']),'-dsvg');
end
function [state,integrated]=energy(r)
c=r.columns;cfg=r.parameters.bridgeCfg;h=cfg.Ts;index=1:numel(r.time)-1;
power=r.stimulus.signals.values(index,6).*r.trace(index,c.dc_current);
copper=cfg.Rs*sum(r.trace(index,c.next_phase_current).^2,2);
speed=r.trace(index,c.speed_mechanical);
loss=r.trace(index,c.bridge_loss)+copper+cfg.B*speed.^2+r.stimulus.signals.values(index,5).*speed;
state=r.trace(:,c.magnetic_energy)+r.trace(:,c.kinetic_energy);
integrated=[0;cumsum(h*(power-loss))];
end
