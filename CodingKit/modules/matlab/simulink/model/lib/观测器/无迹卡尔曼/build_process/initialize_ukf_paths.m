function initialize_ukf_paths()
%INITIALIZE_UKF_PATHS Resolve sibling measurement library and physical model.
module=fileparts(fileparts(mfilename('fullpath')));lib=fileparts(fileparts(module));
ekf=fullfile(lib,'观测器','扩展卡尔曼');plant=fullfile(lib,'永磁同步电机');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')), ...
    fullfile(ekf,'src'),fullfile(ekf,'parameter'),fullfile(ekf,'waveform_analysis'), ...
    fullfile(plant,'src'),fullfile(plant,'parameter'),fullfile(plant,'build_process'));
end
