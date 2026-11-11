function plot_ukf_results()
%PLOT_UKF_RESULTS Export saved UKF waveforms with no visible figure windows.
plot_kalman_observer_results(fileparts(mfilename('fullpath')),'UKF','ukf');
end
