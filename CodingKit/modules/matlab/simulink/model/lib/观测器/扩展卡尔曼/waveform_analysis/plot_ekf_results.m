function plot_ekf_results()
%PLOT_EKF_RESULTS Export the saved EKF waveforms without visible figure windows.
plot_kalman_observer_results(fileparts(mfilename('fullpath')),'EKF','ekf');
end
