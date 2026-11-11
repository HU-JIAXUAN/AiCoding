function plot_speed_profile_results()
%PLOT_SPEED_PROFILE_RESULTS Plot physical rate bounds and actual reset events.
folder=fileparts(mfilename('fullpath'));data=load(fullfile(folder,'profile_results.mat'),'records');r=data.records;
handle=figure('Visible','off','Color','w','Position',[100,100,1100,850]);cleanup=onCleanup(@()close(handle));tiledlayout(3,1);
v=r.asymmetric_rates;nexttile;plot(v.time,v.trace(:,[1,4]));ylabel('Mechanical rad/s');legend('Requested','Limited');grid on;
v=r.disable_reacquire;nexttile;plot(v.time,v.trace(:,[1,4,5]));ylabel('Mechanical rad/s');legend('Requested','Output','Held state');grid on;
v=r.reset_priority;nexttile;plot(v.time,v.trace(:,[4,3]));ylabel('Speed / reset');xlabel('Time (s)');legend('Output rad/s','Reset');grid on;
exportgraphics(handle,fullfile(folder,'profile_clearing.png'),'Resolution',140);
exportgraphics(handle,fullfile(folder,'profile_clearing.svg'),'ContentType','vector');
end
