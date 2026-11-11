function initialize_sensorless_fw(model)
%INITIALIZE_SENSORLESS_FW Load the App's executable M settings locally.
module=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(module,'parameter'),fullfile(module,'src'),fullfile(module,'build_process'),fullfile(module,'waveform_analysis'));
p=sensorless_fw_parameters();workspace=get_param(model,'ModelWorkspace');
names=fieldnames(p);
for k=1:numel(names),assignin(workspace,names{k},p.(names{k}));end
assignin(workspace,'testStim',sensorless_fw_stimulus(p));
end
