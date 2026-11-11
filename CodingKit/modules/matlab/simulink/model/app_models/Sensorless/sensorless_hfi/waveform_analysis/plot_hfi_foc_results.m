function plot_hfi_foc_results(beforeFile)
%PLOT_HFI_FOC_RESULTS Export actual control traces and development regressions.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'foc_results.mat'),'records');r=data.records;
v=r.nominal;t=v.time;average=round(.001/v.parameters.hfiCfg.Ts);
handle=figure('Visible','off','Color','w','Position',[100,100,1150,1000]);tiledlayout(4,1);
nexttile;plot(t,[v.controller_trace(:,1),v.plant_trace(:,4)/v.parameters.pmsmCfg.PolePairs,v.controller_trace(:,2)]);
ylabel('Mechanical rad/s');legend('Reference','Plant','Estimate');grid on;
nexttile;plot(t,[v.controller_trace(:,5),movmean(v.plant_trace(:,5),average),v.parameters.testStim.signals.values(:,1)]);
ylabel('Torque N m');legend('Request','Plant 1 ms mean','Load');grid on;
nexttile;error=v.angle_error;error(v.state_trace(:,4)<.5)=NaN;plot(t,error);ylabel('Enabled angle error rad');grid on;
nexttile;stairs(t,[v.state_trace(:,4),v.state_trace(:,7),v.polarity_trace(:,8)]);ylabel('State');xlabel('Time (s)');
legend('Control active','App fault','Polarity stage');grid on;writeFigure(handle,folder,'foc_tracking');

at=t>=t(end)-.003;zoomTime=1000*(t(at)-t(find(at,1)));
handle=figure('Visible','off','Color','w','Position',[100,100,1150,750]);tiledlayout(2,1);
nexttile;plot(zoomTime,v.voltage_trace(at,1:2));ylabel('Actual voltage V');legend('alpha','beta');grid on;
nexttile;plot(zoomTime,v.controller_trace(at,[8,9,7,6]));ylabel('Current A');xlabel('Window time (ms)');
legend('Measured d','Measured q','Reference d','Reference q');grid on;writeFigure(handle,folder,'foc_hfi_ripple');

v=r.command_reversal;t=v.time;
handle=figure('Visible','off','Color','w','Position',[100,100,1150,750]);tiledlayout(2,1);
nexttile;plot(t,[v.controller_trace(:,1),v.plant_trace(:,4)/v.parameters.pmsmCfg.PolePairs]);ylabel('Mechanical rad/s');legend('Reference','Plant');grid on;
nexttile;plot(t,[v.angle_error,v.state_trace(:,4)]);ylabel('Angle rad / active');xlabel('Time (s)');legend('Angle error','Control active');grid on;
writeFigure(handle,folder,'foc_reversal');

if nargin>0 && isfile(beforeFile)
    old=load(beforeFile,'records');before=struct('half_actual_voltage',old.records.half_actual_voltage,'disable_restart',old.records.disable_restart);clear old;
    after=struct('half_actual_voltage',r.half_actual_voltage,'disable_restart',r.disable_restart);
    save(fullfile(folder,'foc_repair_comparison.mat'),'before','after');
    handle=figure('Visible','off','Color','w','Position',[100,100,1150,1000]);tiledlayout(3,1);
    nexttile;hold on;
    for entry={before.half_actual_voltage,after.half_actual_voltage}
        v=entry{1};e=v.controller_trace(:,[7,6])-v.controller_trace(:,8:9);
        count=round(.01/v.parameters.hfiCfg.Ts);rms=sqrt(movmean(sum(e.^2,2),count));at=v.time>=.12;plot(v.time(at),rms(at));
    end
    ylabel('10 ms current error RMS A');legend('Gain in AW residual','Command feasibility residual');grid on;
    nexttile;hold on;
    for entry={before.disable_restart,after.disable_restart},v=entry{1};plot(v.time,v.controller_trace(:,6));end
    xlim([.78,1.1]);ylabel('q current reference A');legend('Retained speed state','Reset speed profile');grid on;
    nexttile;hold on;
    for entry={before.disable_restart,after.disable_restart},v=entry{1};plot(v.time,v.plant_trace(:,4)/v.parameters.pmsmCfg.PolePairs);end
    ylabel('Mechanical rad/s');xlabel('Time (s)');legend('Before repair','After repair');grid on;
    writeFigure(handle,folder,'foc_repairs');
end
end
function writeFigure(handle,folder,name)
cleanup=onCleanup(@()close(handle));
exportgraphics(handle,fullfile(folder,[name,'.png']),'Resolution',140);
exportgraphics(handle,fullfile(folder,[name,'.svg']),'ContentType','vector');
end
