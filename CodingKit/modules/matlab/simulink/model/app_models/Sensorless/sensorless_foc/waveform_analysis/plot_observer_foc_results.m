function plot_observer_foc_results(r,name,module)
%PLOT_OBSERVER_FOC_RESULTS Plot speed, phase, current and real diagnostics.
if nargin<3,module=fileparts(fileparts(mfilename('fullpath')));end
fig=figure('Visible','off','Position',[100,100,1200,1250]);cleanup=onCleanup(@()close(fig));
tiledlayout(6,1);t=r.time;c=r.controller.trace;cc=r.controller.columns;
plant=r.plant.trace;pc=r.plant.columns;obs=r.observer.trace;oc=r.observer.columns;
nexttile;plot(t,[plant(:,pc.speed_true),obs(:,oc.omega_hat)/r.parameters.pmsmCfg.PolePairs,c(:,cc.speed_reference)]);
ylabel('mechanical rad/s');legend('plant','estimate','request');grid on
title([upper(r.observer_kind),' physical FOC / ',strrep(name,'_',' ')]);
nexttile;error=obs(:,oc.theta_hat)-plant(:,pc.theta_true);
plot(t,atan2(sin(error),cos(error)));ylabel('phase error (rad)');grid on
nexttile;plot(t,[c(:,cc.reference),c(:,cc.control_current)]);
ylabel('control-frame A');legend('d ref','q ref','d measured','q measured');grid on
nexttile;plot(t,[plant(:,pc.torque_true),c(:,cc.torque_request)]);
ylabel('torque (N m)');legend('plant','request');grid on
nexttile
if strcmp(r.observer_kind,'eemf')
    yyaxis left;plot(t,obs(:,[oc.emf_alpha,oc.emf_beta]));ylabel('extended EMF (V)');
    yyaxis right;plot(t,obs(:,oc.observer_residual));ylabel('current residual (A)');
    legend('E alpha','E beta','residual norm');
else
    yyaxis left;plot(t,obs(:,oc.flux_magnitude));ylabel('rotor flux (Wb)');
    yyaxis right;plot(t,obs(:,[oc.observer_residual,oc.compensation_ready]));ylabel('A-equivalent / ready');
    legend('flux magnitude','equivalent residual','compensation ready');
end
grid on
nexttile;plot(t,[c(:,cc.beta),c(:,cc.handover_mode),c(:,cc.handover_fault),obs(:,oc.valid)]);
ylabel('weight / mode');legend('beta','mode','fault','observer valid');xlabel('time (s)');grid on
prefix=[r.observer_kind,'_',name];
exportgraphics(fig,fullfile(module,'waveform_analysis',[prefix,'.png']));
exportgraphics(fig,fullfile(module,'waveform_analysis',[prefix,'.svg']),ContentType='vector');
end
