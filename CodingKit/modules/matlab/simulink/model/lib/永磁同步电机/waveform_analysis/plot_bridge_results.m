function plot_bridge_results(records,module)
%PLOT_BRIDGE_RESULTS Export physical mode, turn-off and rectifier evidence.
if nargin<2,module=fileparts(fileparts(mfilename('fullpath')));end
selected={'coast_short_release','release_forward','rectify_forward'};
prefixes={'bridge_modes','bridge_release','bridge_rectifier'};
for caseIndex=1:numel(selected)
    r=records.(selected{caseIndex});x=r.trace;c=r.columns;t=r.time*1000;cfg=r.parameters.bridgeCfg;
    selection=true(size(t));
    if strcmp(selected{caseIndex},'release_forward'),selection=t<=0.3;end
    x=x(selection,:);t=t(selection);
    fig=figure('Visible','off','Position',[100,100,1200,1200]);cleanup=onCleanup(@()close(fig));tiledlayout(6,1);
    nexttile;plot(t,[r.stimulus.signals.values(selection,4),x(:,c.diode_states)]);
    ylabel('mode / diode');legend('mode 0 off,1 PWM,2 short','a (+lower,-upper)','b','c');grid on
    title(strrep(selected{caseIndex},'_',' '));
    nexttile;plot(t,x(:,c.phase_current));ylabel('phase current (A)');legend('a','b','c');grid on
    nexttile;plot(t,x(:,c.phase_voltage));ylabel('terminal voltage (V)');legend('a','b','c');grid on
    nexttile;plot(t,x(:,c.speed_mechanical));ylabel('mechanical rad/s');grid on
    nexttile;plot(t,[cfg.Vdc*x(:,c.dc_current),sum(x(:,c.phase_voltage).*x(:,c.next_phase_current),2),x(:,c.bridge_loss)]);
    ylabel('interval power (W)');legend('DC into bridge','AC into motor','diode loss');grid on
    nexttile;yyaxis left;plot(t,x(:,c.magnetic_energy));ylabel('magnetic energy (J)');
    yyaxis right;plot(t,x(:,c.kinetic_energy));ylabel('kinetic energy (J)');xlabel('time (ms)');grid on
    exportgraphics(fig,fullfile(module,'waveform_analysis',[prefixes{caseIndex},'.png']));
    exportgraphics(fig,fullfile(module,'waveform_analysis',[prefixes{caseIndex},'.svg']),ContentType='vector');
    clear cleanup
end
end
