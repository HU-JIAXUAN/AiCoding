function initialize_ekf_paths()
%INITIALIZE_EKF_PATHS Load this module and its shared SPMSM process functions.
module=fileparts(fileparts(mfilename('fullpath')));plant=fullfile(fileparts(fileparts(module)),'永磁同步电机');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fileparts(mfilename('fullpath')), ...
    fullfile(plant,'src'),fullfile(plant,'parameter'),fullfile(plant,'build_process'));
end
