function module=initialize_sigmoid_smo_paths()
%INITIALIZE_SIGMOID_SMO_PATHS Register this module and its shared PLL dependency.
module=fileparts(fileparts(mfilename('fullpath')));pll=fullfile(fileparts(fileparts(module)),'相位跟踪');
addpath(fullfile(module,'src'),fullfile(module,'parameter'),fullfile(module,'build_process'), ...
    fullfile(module,'waveform_analysis'),fullfile(pll,'src'),fullfile(pll,'parameter'));
end
